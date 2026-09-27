#!/usr/bin/env python3
"""Save and restore the exact i3 desktop session (X11, Linux Mint).

Blueprint
---------
``save``
  * walk the i3 tree and keep every real workspace (``__i3_scratch`` and the
    dock areas are skipped),
  * dump each workspace's tiling structure with ``i3-save-tree`` and inject the
    window matching criteria (``class``/``instance``) into the ``swallows``
    arrays, so ``i3-msg append_layout`` can rebuild tabs/splits/stacking,
  * record one launch recipe per window:
      - kitty     -> cwd (+ every tab/split via a generated kitty session file)
      - firefox   -> sessionstore copy, restores the exact tabs/windows
      - brave/edge/chromium -> ``Sessions/`` copy + ``--restore-last-session``
      - VS Code   -> the project folder the window had open
      - anything else -> ``Exec=`` line from its ``.desktop`` entry
  * copy the browser session folders into the state dir,
  * drop a ``pending`` flag so the next login knows it should restore.

``restore``
  * re-create every workspace and append its saved layout (this plants i3
    placeholder windows), then start the recorded apps; i3 swallows each new
    window into its placeholder, so tabs/splits/geometry come back,
  * reconcile: windows that landed on the wrong workspace are moved to the
    recorded one, placeholders whose app never came back are killed, and the
    previously focused workspace/window is focused again.

Everything uses the stdlib plus tools already installed on this machine
(``python3``, ``i3-msg``, ``i3-save-tree``, ``wmctrl``/``xprop``, ``flatpak``).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

HOME = Path.home()
DEFAULT_STATE = HOME / ".local/state/i3-session"
STATE_DIR = Path(os.environ.get("I3_SESSION_STATE") or DEFAULT_STATE)
LOG_FILE: Path | None = None

# Shells are never "the program to relaunch": the terminal already starts one.
SHELL_NAMES = {"sh", "bash", "zsh", "fish", "dash", "ksh", "nu", "csh", "tcsh"}

# Commands that must never be re-run automatically at login (they mutate state,
# need a network prompt, or would start long builds).
UNSAFE_CMD_RE = re.compile(
    r"(^|[;&|()<>\s$`])("
    r"rm|rmdir|mv|cp|dd|shred|wipefs|mkfs\S*|fdisk|parted|sgdisk|mkswap|"
    r"sudo|doas|su|pkexec|passwd|chpasswd|"
    r"apt|apt-get|aptitude|dpkg|snap|pacman|yay|paru|zypper|dnf|rpm|nix|nix-env|"
    r"pip|pip3|npm|yarn|pnpm|bun|deno|composer|gem|"
    r"systemctl|service|loginctl|shutdown|reboot|poweroff|halt|telinit|init|"
    r"kill|killall|pkill|xkill|"
    r"git|gh|docker|podman|nerdctl|kubectl|terraform|ansible|helm|vagrant|"
    r"curl|wget|rsync|scp|sftp|ssh-keygen|gpg|"
    r"make|cmake|ninja|gradle|mvn|cargo|rustc|flutter|dart|gcc|g\+\+|clang|"
    r"truncate|chmod|chown|mount|umount|swapoff|"
    r"lynis|clamav|bleachbit|timeshift"
    r")(\s|$)")

CHROMIUM_FAMILY = {
    "brave-browser": ("brave-browser", "BraveSoftware/Brave-Browser"),
    "brave": ("brave-browser", "BraveSoftware/Brave-Browser"),
    "chromium": ("chromium", "chromium"),
    "chromium-browser": ("chromium", "chromium"),
    "google-chrome": ("google-chrome", "google-chrome"),
    "google-chrome-stable": ("google-chrome", "google-chrome"),
    "microsoft-edge": ("microsoft-edge", "microsoft-edge"),
    "microsoft-edge-stable": ("microsoft-edge", "microsoft-edge"),
    "vivaldi": ("vivaldi", "vivaldi"),
    "vivaldi-stable": ("vivaldi", "vivaldi"),
}
CHROMIUM_SESSION_FILES = (
    "Current Session",
    "Current Tabs",
    "Last Session",
    "Last Tabs",
)

# --------------------------------------------------------------------------- #
# logging / process helpers
# --------------------------------------------------------------------------- #
def start_log(name: str) -> None:
    global LOG_FILE
    try:
        log_dir = STATE_DIR / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        LOG_FILE = log_dir / name
    except OSError:
        LOG_FILE = None


def log(msg: str) -> None:
    line = "[%s] %s" % (datetime.now().strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    if LOG_FILE:
        try:
            with open(LOG_FILE, "a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        except OSError:
            pass


def run(cmd, **kwargs):
    """Run a command; never raise, always return a CompletedProcess."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    except (OSError, subprocess.SubprocessError) as exc:
        return subprocess.CompletedProcess(cmd, 127, "", str(exc))


def i3_msg(payload: str, msgtype: str | None = None):
    cmd = ["i3-msg"]
    if msgtype:
        cmd += ["-t", msgtype]
    cmd.append(payload)
    return run(cmd)


def i3_tree():
    res = run(["i3-msg", "-t", "get_tree"])
    try:
        return json.loads(res.stdout)
    except (ValueError, TypeError):
        log("!! could not read the i3 tree: %s" % (res.stderr or res.stdout).strip())
        return None


def i3_workspaces():
    res = run(["i3-msg", "-t", "get_workspaces"])
    try:
        return json.loads(res.stdout)
    except (ValueError, TypeError):
        return []


def walk_tree(node):
    """Yield every node of the i3 tree (depth first)."""
    yield node
    for child in (node.get("nodes") or []) + (node.get("floating_nodes") or []):
        yield from walk_tree(child)


def real_workspaces(tree):
    """Workspaces a human works in (skips __i3_scratch / internal names)."""
    if not tree:
        return []
    return [
        node for node in walk_tree(tree)
        if node.get("type") == "workspace" and not str(node.get("name", "")).startswith("__")
    ]


def proc_cwd(pid: int | None) -> str | None:
    try:
        return os.readlink("/proc/%d/cwd" % pid)
    except (OSError, TypeError):
        return None


def proc_exe(pid: int | None) -> str | None:
    try:
        return os.readlink("/proc/%d/exe" % pid)
    except (OSError, TypeError):
        return None


def proc_cmdline(pid: int | None) -> list[str]:
    if not pid:
        return []
    try:
        with open("/proc/%d/cmdline" % pid, "rb") as fh:
            raw = fh.read()
    except OSError:
        return []
    return [part.decode("utf-8", "replace") for part in raw.split(b"\0") if part]


def window_pids() -> dict[int, int]:
    """Map X11 window id -> pid.

    wmctrl is the fast path, but it aborts completely when the root window's
    client list still holds a window that has already been destroyed, so the
    i3 tree plus xprop is used as the fallback.
    """
    pids: dict[int, int] = {}
    res = run(["wmctrl", "-lp"])
    for line in res.stdout.splitlines():
        parts = line.split(None, 4)
        if len(parts) < 3 or not parts[0].startswith("0x"):
            continue
        try:
            pids[int(parts[0], 16)] = int(parts[2])
        except ValueError:
            continue
    if pids:
        return pids
    tree = i3_tree()
    for node in walk_tree(tree) if tree else []:
        window_id = node.get("window")
        if window_id:
            pid = xprop_pid(window_id)
            if pid:
                pids[window_id] = pid
    return pids



def xprop_pid(win_id: int) -> int | None:
    res = run(["xprop", "-id", hex(win_id), "_NET_WM_PID"])
    match = re.search(r"=\s*(\d+)", res.stdout)
    return int(match.group(1)) if match else None


def flatpak_pid_map() -> dict[int, str]:
    """Map pid -> flatpak application id for every running flatpak app."""
    out: dict[int, str] = {}
    res = run(["flatpak", "ps", "--columns=instance,pid"])
    for line in res.stdout.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        app_id, pid = parts[0], parts[1].rstrip("?")
        if pid.isdigit():
            out.setdefault(int(pid), app_id)
    return out


def find_flatpak_app(pid: int | None, app_map: dict[int, str]) -> str | None:
    """Walk up the process tree until the pid is covered by a flatpak app."""
    if not pid:
        return None
    seen: set[int] = set()
    current: int | None = pid
    while current and current not in seen:
        seen.add(current)
        if current in app_map:
            return app_map[current]
        try:
            with open("/proc/%d/stat" % current) as fh:
                fields = fh.read().rsplit(")", 1)[1].split()
            current = int(fields[1])
        except (OSError, ValueError, IndexError):
            return None
    return None


# --------------------------------------------------------------------------- #
# .desktop fallback: how to relaunch an app we have no dedicated recipe for
# --------------------------------------------------------------------------- #
DESKTOP_DIRS = [
    HOME / ".local/share/applications",
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
    Path("/var/lib/flatpak/exports/share/applications"),
    HOME / ".local/share/flatpak/exports/share/applications",
]


def parse_desktop_file(path: Path) -> dict:
    """Return the [Desktop Entry] keys we care about."""
    entry: dict[str, str] = {}
    in_main = False
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            in_main = line == "[Desktop Entry]"
            continue
        if not in_main or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.strip() in ("Name", "Exec", "StartupWMClass", "Terminal", "NoDisplay", "Type"):
            entry.setdefault(key.strip(), value.strip())
    return entry


def desktop_exec_args(exec_line: str) -> list[str]:
    """Turn `Exec=env FOO=1 app %U` into a clean argv list."""
    try:
        parts = shlex.split(exec_line)
    except ValueError:
        return []
    args = [part for part in parts
            if not (part.startswith("%") and len(part) <= 2)
            and not re.fullmatch(r"@@[A-Za-z]*", part)]  # flatpak file-forwarding
    while args and os.path.basename(args[0]) == "env":
        args.pop(0)
        while args and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", args[0]):
            args.pop(0)
    return args


def desktop_index() -> list[dict]:
    """Every launchable .desktop entry, normalized for WM_CLASS matching."""
    index: list[dict] = []
    for folder in DESKTOP_DIRS:
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.desktop")):
            entry = parse_desktop_file(path)
            if not entry.get("Exec") or entry.get("Type", "Application") != "Application":
                continue
            if entry.get("NoDisplay", "").lower() == "true":
                continue
            args = desktop_exec_args(entry["Exec"])
            if not args:
                continue
            index.append({
                "path": str(path),
                "name": entry.get("Name", "").lower(),
                "wm_class": (entry.get("StartupWMClass") or "").lower(),
                "exe": os.path.basename(args[0]).lower(),
                "args": args,
            })
    return index


def generic_command(win: dict, index: list[dict]) -> list[str] | None:
    """Best-effort relaunch command for an arbitrary window."""
    cls = (win.get("class") or "").lower()
    inst = (win.get("instance") or "").lower()
    exe = os.path.basename(proc_exe(win.get("pid")) or "").lower()
    for entry in index:
        if entry["wm_class"] and entry["wm_class"] in (cls, inst):
            return list(entry["args"])
    for entry in index:
        if entry["exe"] and entry["exe"] in (cls, inst, exe):
            return list(entry["args"])
    for entry in index:
        if entry["name"] and entry["name"] == cls:
            return list(entry["args"])
    return None


# --------------------------------------------------------------------------- #
# kitty: exact tabs / splits / cwd
# --------------------------------------------------------------------------- #
def _executable(*candidates: Path) -> str | None:
    for cand in candidates:
        if cand.exists() and os.access(cand, os.X_OK):
            return str(cand)
    return None


def kitty_binary() -> str:
    return _executable(HOME / ".local/kitty.app/bin/kitty", Path("/usr/bin/kitty")) or "kitty"


def kitten_binary() -> list[str]:
    """`kitten` when installed, otherwise kitty's built-in `@` sub-command."""
    found = _executable(HOME / ".local/kitty.app/bin/kitten", Path("/usr/bin/kitten"))
    return [found, "@"] if found else [kitty_binary(), "@"]


def kitty_socket_candidates() -> list[str]:
    candidates: list[str] = []
    env = os.environ.get("KITTY_LISTEN_ON")
    if env:
        candidates.append(env)
    try:
        conf = (HOME / ".config/kitty/kitty.conf").read_text(encoding="utf-8", errors="replace")
        for line in conf.splitlines():
            line = line.strip()
            if line.startswith("listen_on"):
                value = line[len("listen_on"):].strip()
                if value:
                    candidates.append(value)
    except OSError:
        pass
    candidates += ["unix:@kitty-session-restore", "/tmp/kitty-session-restore"]
    return list(dict.fromkeys(candidates))


def kitty_ls() -> tuple[str | None, list]:
    """Talk to a running kitty over remote control; returns (socket, os_windows)."""
    for socket in kitty_socket_candidates():
        res = run(kitten_binary() + ["--to", socket, "ls"])
        if res.returncode != 0 or not res.stdout.strip():
            continue
        try:
            data = json.loads(res.stdout)
        except ValueError:
            continue
        if isinstance(data, dict):  # safety net for a different JSON shape
            data = data.get("os-windows") or data.get("os_windows") or []
        if data:
            return socket, data
    return None, []


# Programs worth re-running in a restored terminal tab: interactive tools where
# "where I left off" actually means something. Everything else (servers, build
# scripts, one-shot commands) gets a plain shell in the right directory.
INTERACTIVE_PROGRAMS = {
    "nvim", "vim", "vi", "view", "nano", "pico", "emacs", "helix", "hx", "kak",
    "htop", "btop", "top", "atop", "glances", "iftop", "iotop",
    "lazygit", "lazydocker", "tig", "tmux", "screen", "ssh", "mosh", "telnet",
    "mutt", "neomutt", "aerc", "irssi", "weechat", "newsboat", "nnn", "vifm",
    "ncdu", "duf", "ranger", "yazi", "mc", "fzf", "fzy", "gdb", "ipython",
    "psql", "mysql", "sqlite3", "redis-cli", "mongosh", "k9s",
    "cline", "codex", "gemini", "qwen", "opencode", "aider", "crush",
}


def program_to_relaunch(window: dict) -> list[str] | None:
    """The program a terminal window runs right now, if it is safe to replay."""
    if window.get("at_prompt"):
        return None  # idle shell -> just `launch`
    candidates: list[list[str]] = []
    for proc in window.get("foreground_processes") or []:
        if proc.get("cmdline"):
            candidates.append(list(proc["cmdline"]))
    if window.get("cmdline"):
        candidates.append(list(window["cmdline"]))
    replay_any = os.environ.get("I3_SESSION_REPLAY_ANY") == "1"
    for cmdline in candidates:
        joined = " ".join(cmdline)
        if any(token in joined for token in ("|", "&&", ";", "$(", ">", "<", "`")):
            continue  # pipelines are not worth replaying unattended
        names = {os.path.basename(arg).lower() for arg in cmdline}
        if names & SHELL_NAMES:
            continue
        if any(UNSAFE_CMD_RE.search(name) for name in names) \
                or UNSAFE_CMD_RE.search(" ".join(cmdline[1:])):
            continue
        stems = {os.path.splitext(name)[0] for name in names}
        if replay_any or (stems & INTERACTIVE_PROGRAMS):
            return cmdline
    return None


def kitty_session_file(os_window: dict, dest: Path) -> dict:
    """Write a kitty session file that recreates one OS window (all its tabs)."""
    lines: list[str] = []
    tabs_meta: list[dict] = []
    for tab in os_window.get("tabs") or []:
        lines.append("new_tab")
        if tab.get("layout"):
            lines.append("layout %s" % tab["layout"])
        if tab.get("enabled_layouts"):
            lines.append("enabled_layouts %s" % ",".join(tab["enabled_layouts"]))
        windows_meta: list[dict] = []
        for win_index, window in enumerate(tab.get("windows") or []):
            if win_index:
                lines.append("new_window")
            cwd = window.get("cwd")
            if not cwd:
                for proc in window.get("foreground_processes") or []:
                    if proc.get("cwd"):
                        cwd = proc["cwd"]
                        break
            if cwd:
                lines.append("cd %s" % shlex.quote(cwd))
            program = program_to_relaunch(window)
            if program:
                lines.append("launch %s" % " ".join(shlex.quote(a) for a in program))
            else:
                lines.append("launch")
            windows_meta.append({"title": window.get("title"), "cwd": cwd, "program": program})
        tabs_meta.append({"title": tab.get("title"), "windows": windows_meta})
        lines.append("")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {"file": str(dest), "tabs": tabs_meta}


# --------------------------------------------------------------------------- #
# browsers: "exact tabs" comes from their own session stores
# --------------------------------------------------------------------------- #
def firefox_profile(pid: int | None = None) -> Path | None:
    """The Firefox profile in use: running instance first, else the newest one."""
    cmdline = proc_cmdline(pid)
    for index, arg in enumerate(cmdline):
        if arg in ("-profile", "--profile") and index + 1 < len(cmdline):
            candidate = Path(cmdline[index + 1])
            if candidate.is_dir():
                return candidate
    root = HOME / ".mozilla/firefox"
    if not root.is_dir():
        return None
    best: Path | None = None
    best_mtime = -1.0
    for profile in root.iterdir():
        if not profile.is_dir() or profile.name.startswith("."):
            continue
        for stamp in (
            profile / "sessionstore-backups" / "recovery.jsonlz4",
            profile / "sessionstore.jsonlz4",
            profile / "prefs.js",
        ):
            try:
                mtime = stamp.stat().st_mtime
            except OSError:
                continue
            if mtime > best_mtime:
                best, best_mtime = profile, mtime
    return best


def firefox_save(profile: Path, dest: Path) -> dict:
    """Copy the live session store of a Firefox profile into the state dir."""
    dest.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for name in ("sessionstore.jsonlz4",
                 "sessionstore-backups/recovery.jsonlz4",
                 "sessionstore-backups/recovery.baklz4",
                 "sessionstore-backups/previous.jsonlz4"):
        src = profile / name
        if src.is_file():
            shutil.copy2(src, dest / Path(name).name)
            copied.append(name)
    return {"profile": str(profile), "dir": str(dest), "files": copied}


def set_firefox_pref(profile: Path, key: str, value: str) -> None:
    """Set/replace one user_pref in prefs.js (only called while Firefox is closed)."""
    prefs = profile / "prefs.js"
    try:
        text = prefs.read_text(encoding="utf-8", errors="replace") if prefs.exists() else ""
    except OSError:
        return
    line = 'user_pref("%s", %s);' % (key, value)
    pattern = re.compile(r'^user_pref\("%s",.*?\);\s*$' % re.escape(key), re.M)
    text = pattern.sub(line, text) if pattern.search(text) else text.rstrip("\n") + "\n" + line + "\n"
    try:
        prefs.write_text(text, encoding="utf-8")
    except OSError:
        pass


def firefox_restore(payload: dict) -> str | None:
    """Put the saved tabs back and tell Firefox to restore them on start."""
    profile = Path(payload.get("profile") or "")
    saved = Path(payload.get("dir") or "")
    if not profile.is_dir() or not saved.is_dir():
        return "firefox: saved profile or session store is missing"
    source = None
    for name in ("sessionstore.jsonlz4", "recovery.jsonlz4", "recovery.baklz4", "previous.jsonlz4"):
        if (saved / name).is_file():
            source = saved / name
            break
    if source:
        (profile / "sessionstore-backups").mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, profile / "sessionstore.jsonlz4")
        shutil.copy2(source, profile / "sessionstore-backups" / "recovery.jsonlz4")
    set_firefox_pref(profile, "browser.startup.page", "3")
    set_firefox_pref(profile, "browser.sessionstore.resume_from_crash", "true")
    return None


def chromium_info(win: dict, flatpak_map: dict[int, str]) -> dict | None:
    """Work out browser/profile/location for a Chromium-based window."""
    cls = (win.get("class") or "").lower()
    key = next((c for c in CHROMIUM_FAMILY if cls == c or cls.startswith(c)), None)
    if not key:
        return None
    binary, rel_root = CHROMIUM_FAMILY[key]
    cmdline = proc_cmdline(win.get("pid"))
    profile_dir = "Default"
    user_data_dir = None
    for arg in cmdline:
        if arg.startswith("--profile-directory="):
            profile_dir = arg.split("=", 1)[1]
        elif arg.startswith("--user-data-dir="):
            user_data_dir = arg.split("=", 1)[1]
    app_id = find_flatpak_app(win.get("pid"), flatpak_map)
    if app_id:
        root = HOME / ".var/app" / app_id / "config" / rel_root
        cmd = ["flatpak", "run", app_id, "--restore-last-session",
               "--profile-directory=" + profile_dir]
    else:
        root = Path(user_data_dir) if user_data_dir else HOME / ".config" / rel_root
        exe = _executable(Path("/opt/brave.com/brave/brave-browser"), Path("/usr/bin") / binary)
        cmd = [exe or binary, "--restore-last-session", "--profile-directory=" + profile_dir]
    return {
        "key": key,
        "cmd": cmd,
        "profile": root / profile_dir,
        "app_id": app_id,
        "group": "chromium:%s:%s" % (key, profile_dir),
    }


def chromium_save(payload: dict, dest: Path) -> dict:
    """Copy Chrome's `Sessions` folder (plus any legacy session files)."""
    profile = Path(payload.get("profile") or "")
    dest.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    if (profile / "Sessions").is_dir():
        shutil.copytree(profile / "Sessions", dest / "Sessions", dirs_exist_ok=True)
        copied.append("Sessions")
    for name in CHROMIUM_SESSION_FILES:
        if (profile / name).is_file():
            shutil.copy2(profile / name, dest / name)
            copied.append(name)
    return {"profile": str(profile), "dir": str(dest), "files": copied}


def chromium_restore(payload: dict) -> str | None:
    profile = Path(payload.get("profile") or "")
    saved = Path(payload.get("dir") or "")
    if not saved.is_dir():
        return "chromium: saved session folder is missing"
    try:
        profile.mkdir(parents=True, exist_ok=True)
        if (saved / "Sessions").is_dir():
            shutil.copytree(saved / "Sessions", profile / "Sessions", dirs_exist_ok=True)
        for name in CHROMIUM_SESSION_FILES:
            if (saved / name).is_file():
                shutil.copy2(saved / name, profile / name)
    except OSError as exc:
        return "chromium: %s" % exc
    return None


# --------------------------------------------------------------------------- #
# per-app launch recipes
# --------------------------------------------------------------------------- #
def vs_code_folders() -> dict[str, str]:
    """Map lowercased project folder name -> path, from VS Code's own state."""
    folders: dict[str, str] = {}
    for state in (
        HOME / ".config/Code/User/globalStorage/storage.json",
        HOME / ".config/VSCodium/User/globalStorage/storage.json",
        HOME / ".config/Code - OSS/User/globalStorage/storage.json",
    ):
        try:
            data = json.loads(state.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        windows_state = data.get("windowsState") or {}
        entries = []
        if isinstance(windows_state.get("lastActiveWindow"), dict):
            entries.append(windows_state["lastActiveWindow"])
        entries += windows_state.get("openedWindows") or []
        for entry in entries:
            folder = (entry or {}).get("folder")
            if not folder or not folder.startswith("file://"):
                continue
            path = folder[len("file://"):]
            folders.setdefault(os.path.basename(path).lower(), path)
    return folders


def title_tail(title: str, suffix: str) -> str | None:
    """Strip `suffix` from a window title and return the trailing name chunk."""
    cleaned = re.sub(r"\s+-\s+%s\s*$" % re.escape(suffix), "", title or "").strip()
    if not cleaned:
        return None
    return re.split(r"\s+-\s+", cleaned)[-1].strip()


def locate_folder(name: str, max_depth: int = 3) -> Path | None:
    """Find a directory by name under $HOME (used when only the title is known).

    Bounded on purpose: it runs while shutting down and only for windows whose
    directory is not a direct child of $HOME.
    """
    if not name or "/" in name or name in (".", ".."):
        return None
    res = run(["find", str(HOME), "-maxdepth", str(max_depth), "-type", "d",
               "-name", name, "-not", "-path", "*/.git/*",
               "-not", "-path", "*/node_modules/*", "-not", "-path", "*/.cache/*"])
    if res.returncode != 0:
        return None
    for line in res.stdout.splitlines():
        candidate = Path(line.strip())
        if candidate.is_dir():
            return candidate
    return None


def classify_window(win: dict, ctx: dict) -> dict:
    """Return {'kind', 'cmd', 'group', 'note'} for one window."""
    cls = (win.get("class") or "").lower()
    title = win.get("title") or ""

    if cls in ("kitty", "startupkitty", "xterm-256color") or cls.startswith("kitty"):
        # A non-default class (their startup kitty uses --class StartupKitty) has
        # to be reproduced, otherwise the relaunched window cannot match the
        # placeholder that was saved for it.
        launcher = [kitty_binary()]
        if win.get("class") and cls != "kitty":
            launcher += ["--class", win["class"]]
            if win.get("instance") and win["instance"] != win["class"]:
                launcher += ["--name", win["instance"]]
        entry = ctx["kitty_windows"].get(win["xid"])
        if entry:
            return {"kind": "kitty", "cmd": launcher + ["--session", entry["file"]],
                    "group": "kitty:%s" % win["xid"],
                    "note": "kitty session, %d tab(s)" % len(entry["tabs"])}
        cwd = proc_cwd(win.get("pid"))
        if cwd and os.path.isdir(cwd):
            launcher += ["--directory", cwd]
        return {"kind": "kitty", "cmd": launcher, "group": "kitty:%s" % win["xid"],
                "note": "kitty cwd=%s" % (cwd or "unknown")}

    if cls == "firefox" and ctx.get("firefox"):
        profile = ctx["firefox"]["profile"]
        return {"kind": "firefox", "cmd": ["firefox", "--profile", profile],
                "group": "firefox:%s" % profile, "note": "tabs via sessionstore"}

    info = chromium_info(win, ctx["flatpak_map"])
    if info and ctx.get("chromium_info_allowed", True):
        ctx["chromium"].setdefault(info["group"], info)
        return {"kind": "chromium", "cmd": info["cmd"], "group": info["group"],
                "note": "tabs via --restore-last-session"}

    if cls in ("code", "code - oss", "vscode", "vscodium"):
        exe = _executable(Path("/usr/bin/code"), Path("/usr/bin/code-oss"), Path("/usr/bin/codium"))
        folder = None
        tail = title_tail(title, "Visual Studio Code")
        if tail:
            folder = ctx["code_folders"].get(tail.lower())
        cmd = [exe or "code"] + ([folder] if folder else [])
        return {"kind": "code", "cmd": cmd, "group": "code:%s" % win["xid"],
                "note": "folder %s" % folder if folder else "reopens its own last window"}

    if cls == "thunar":
        name = title_tail(title, "Thunar")
        cmd = ["thunar"]
        target = HOME / name if name else None
        if name and not (target and target.is_dir()):
            target = locate_folder(name)
        if target and target.is_dir():
            cmd.append(str(target))
        return {"kind": "filemanager", "cmd": cmd, "group": "thunar:%s" % win["xid"],
                "note": "opened in %s" % (target or HOME)}

    cmd = generic_command(win, ctx["desktop"])
    return {"kind": "generic", "cmd": cmd or [], "group": "generic:%s" % win["xid"],
            "note": "from .desktop entry" if cmd else "no launch recipe found"}


# --------------------------------------------------------------------------- #
# save
# --------------------------------------------------------------------------- #
def collect_window_nodes(node, floating=False):
    """Window leaves of a workspace in tree (left-to-right/depth-first) order."""
    children = node.get("nodes") or []
    float_children = node.get("floating_nodes") or []
    out: list[tuple[dict, bool]] = []
    for child in children:
        out.extend(collect_window_nodes(child, floating))
    for child in float_children:
        out.extend(collect_window_nodes(child, True))
    if not children and not float_children and node.get("window"):
        out.append((node, floating))
    return out


def json_stream_ok(text: str) -> bool:
    """True when `text` is a stream of one or more JSON objects (i3 layout files)."""
    decoder = json.JSONDecoder()
    index, count = 0, 0
    while index < len(text):
        while index < len(text) and text[index] in " \t\r\n":
            index += 1
        if index >= len(text):
            break
        try:
            _value, index = decoder.raw_decode(text, index)
        except ValueError:
            return False
        count += 1
    return count > 0


def write_layout(workspace_name: str, dest: Path) -> tuple[bool, str]:
    """Dump a workspace with i3-save-tree and fill in the swallow criteria.

    Note that i3-save-tree writes one top-level object per direct child of the
    workspace (a two-window workspace yields two objects) - i3's append_layout
    consumes that stream, so the file is passed through as produced.
    """
    res = run(["i3-save-tree", "--workspace", workspace_name])
    if res.returncode != 0 or not res.stdout.strip():
        return False, "i3-save-tree failed: %s" % (res.stderr or res.stdout).strip()
    if '"swallows"' not in res.stdout:
        return False, "workspace has no windows"

    def fix_swallows(match: "re.Match[str]") -> str:
        block = match.group(0)
        # Only the `class` half of WM_CLASS is used. i3 ANDs every key in the
        # criteria, and the instance half is not stable between launches
        # (Thunar reports "Thunar" on one boot and "thunar" on the next), which
        # would mean the window never gets swallowed into its placeholder.
        found = re.search(r'//\s*"class":\s*("[^"]+")', block)
        if found:
            return ('"swallows": [\n        {\n           "class": %s\n        }\n    ],'
                    % found.group(1))
        instance = re.search(r'//\s*"instance":\s*("[^"]+")', block)
        if instance:
            return ('"swallows": [\n        {\n           "instance": %s\n        }\n    ],'
                    % instance.group(1))
        return block  # nothing to match on: leave i3-save-tree's output alone

    text = "\n".join(
        line for line in res.stdout.splitlines() if not line.strip().startswith("// vim")
    )
    text = re.sub(r'"swallows":\s*\[[^\]]*\],', fix_swallows, text, flags=re.S)
    if not json_stream_ok(text):
        return False, "generated layout is not a valid JSON stream"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text + "\n", encoding="utf-8")
    return True, str(dest)


def save_session(dry_run: bool = False) -> int:
    tree = i3_tree()
    if not tree:
        return 1
    workspaces = real_workspaces(tree)
    pids = window_pids()
    flatpak_map = flatpak_pid_map()
    desktop = desktop_index()
    kitty_socket, kitty_os_windows = kitty_ls()

    ctx = {
        "kitty_windows": {},
        "code_folders": vs_code_folders(),
        "flatpak_map": flatpak_map,
        "desktop": desktop,
        "chromium": {},
        "firefox": None,
        "kitty_socket": kitty_socket,
    }

    raw_windows: list[tuple[dict, dict, bool]] = []
    for workspace in workspaces:
        for node, floating in collect_window_nodes(workspace):
            raw_windows.append((workspace, node, floating))

    # Firefox needs its profile resolved before the windows are classified.
    for _workspace, node, _floating in raw_windows:
        props = node.get("window_properties") or {}
        if (props.get("class") or "").lower() == "firefox":
            pid = pids.get(node["window"]) or xprop_pid(node["window"])
            profile = firefox_profile(pid)
            if profile:
                ctx["firefox"] = {"profile": str(profile)}
            break

    # kitty session files: one per OS window, keeps tabs/splits/cwd
    for os_window in kitty_os_windows:
        window_id = os_window.get("platform_window_id")
        if not isinstance(window_id, int):
            continue
        dest = STATE_DIR / "kitty" / ("kitty-win-%d.session" % window_id)
        if dry_run:
            ctx["kitty_windows"][window_id] = {
                "file": str(dest),
                "tabs": [
                    {"title": tab.get("title"),
                     "windows": [w.get("title") for w in tab.get("windows") or []]}
                    for tab in os_window.get("tabs") or []
                ],
            }
        else:
            ctx["kitty_windows"][window_id] = kitty_session_file(os_window, dest)

    records: list[dict] = []
    for workspace, node, floating in raw_windows:
        props = node.get("window_properties") or {}
        xid = node["window"]
        record = {
            "xid": xid,
            "xid_hex": hex(xid),
            "con_id": node.get("id"),
            "pid": pids.get(xid) or xprop_pid(xid),
            "class": props.get("class") or "",
            "instance": props.get("instance") or "",
            "title": props.get("title") or node.get("name") or "",
            "workspace": workspace["name"],
            "floating": floating,
            "geometry": node.get("geometry") or {},
        }
        record.update(classify_window(record, ctx))
        records.append(record)

    # browser session stores (only the browser can explain that state)
    for group, info in ctx["chromium"].items():
        dest = STATE_DIR / "chromium" / group.replace(":/", "_")
        info["state"] = ({"dir": str(dest), "files": ["(dry run)"]} if dry_run
                         else chromium_save(info, dest))
    if ctx["firefox"]:
        profile = Path(ctx["firefox"]["profile"])
        dest = STATE_DIR / "firefox" / profile.name
        ctx["firefox"]["state"] = ({"dir": str(dest), "files": ["(dry run)"]} if dry_run
                                   else firefox_save(profile, dest))

    # one launch entry per app instance (grouped apps like a browser launch once)
    launches: dict[str, dict] = {}
    for record in records:
        if not record["cmd"]:
            record["launch_id"] = None
            continue
        launch = launches.get(record["group"])
        if launch is None:
            launch = {
                "id": record["group"],
                "kind": record["kind"],
                "cmd": record["cmd"],
                "workspace": record["workspace"],
                "covers": [],
                "note": record["note"],
            }
            launches[record["group"]] = launch
        launch["covers"].append(record["xid_hex"])
        record["launch_id"] = record["group"]

    ws_data = []
    targets = []
    for workspace in workspaces:
        ws_windows = [r for r in records if r["workspace"] == workspace["name"]]
        if not ws_windows:
            continue
        layout_path = STATE_DIR / "layouts" / (
            "ws-%s.json" % re.sub(r"[^A-Za-z0-9_.-]", "_", workspace["name"])
        )
        targets.append((workspace, layout_path, ws_windows))

    layout_results: dict = {}
    if dry_run:
        for workspace, _path, _windows in targets:
            layout_results[workspace["name"]] = (True, "(dry run)")
    else:
        # i3-save-tree dumps the whole tree for every workspace, so the calls are
        # independent work: run them together instead of one after another.
        with ThreadPoolExecutor(max_workers=min(4, max(1, len(targets)))) as pool:
            futures = {pool.submit(write_layout, workspace["name"], path): workspace["name"]
                       for workspace, path, _windows in targets}
            for future, name in futures.items():
                try:
                    layout_results[name] = future.result()
                except Exception as exc:  # noqa: BLE001
                    layout_results[name] = (False, "%s: %s" % (type(exc).__name__, exc))

    for workspace, layout_path, ws_windows in targets:
        layout_ok, layout_message = layout_results.get(workspace["name"], (True, ""))
        if not layout_ok:
            log("!! workspace %s: no layout saved (%s)" % (workspace["name"], layout_message))
        ws_data.append({
            "name": workspace["name"],
            "num": workspace.get("num"),
            "layout": str(layout_path) if layout_ok else None,
            "launch_ids": [l["id"] for l in launches.values() if l["workspace"] == workspace["name"]],
            "windows": [r["xid_hex"] for r in ws_windows],
        })

    focused_ws = next((w["name"] for w in i3_workspaces() if w.get("focused")), None)
    focused_window = None
    for workspace in workspaces:
        if workspace["name"] != focused_ws:
            continue
        for node in walk_tree(workspace):
            if node.get("focused") and node.get("window"):
                props = node.get("window_properties") or {}
                focused_window = {"class": props.get("class"), "instance": props.get("instance"),
                                  "title": props.get("title")}
    session = {
        "version": 1,
        "saved_at": datetime.now().isoformat(timespec="seconds"),
        "kitty_socket": kitty_socket,
        "focused_workspace": focused_ws,
        "focused_window": focused_window,
        "app_state": {"firefox": ctx["firefox"], "chromium": ctx["chromium"]},
        "launches": list(launches.values()),
        "workspaces": ws_data,
        "windows": records,
    }

    log("%s session: %d workspace(s), %d window(s), %d launch(es)" % (
        "(dry run)" if dry_run else "saved", len(ws_data), len(records), len(launches)))
    for record in records:
        log("   ws %-4s %-12s %-45s -> %s" % (
            record["workspace"], record["class"][:12], record["title"][:45],
            " ".join(record["cmd"]) if record["cmd"] else "(no launch recipe)"))

    if dry_run:
        log("dry run: nothing written to %s" % STATE_DIR)
        return 0

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_DIR / "session.json.tmp"
    tmp.write_text(json.dumps(session, indent=2, default=str) + "\n", encoding="utf-8")
    os.replace(tmp, STATE_DIR / "session.json")
    (STATE_DIR / "pending").write_text(session["saved_at"] + "\n", encoding="utf-8")
    log("wrote %s (pending restore flag set)" % (STATE_DIR / "session.json"))
    return 0
# --------------------------------------------------------------------------- #
# restore
# --------------------------------------------------------------------------- #
WAIT_SECONDS = int(os.environ.get("I3_SESSION_WAIT", "20"))
# Slow starters (flatpak packages, cold Electron apps) get a second, quiet watch
# window in the background before their placeholders are cleaned up.
LATE_WATCH_SECONDS = int(os.environ.get("I3_SESSION_LATE_WATCH", "90"))


def i3_quote(value) -> str:
    """Quote a workspace name for an i3 command."""
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', '\\"')


def i3_ok(res) -> bool:
    return '"success":true' in (res.stdout or "").replace(" ", "")


def launch_process(cmd: list[str]):
    try:
        return subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as exc:
        log("!! cannot launch %s: %s" % (" ".join(cmd), exc))
        return None


def live_windows(tree) -> list[dict]:
    """Every real (non-placeholder) window with the workspace it sits on."""
    out = []
    for workspace in real_workspaces(tree):
        for node in walk_tree(workspace):
            if node.get("window") and not node.get("swallows"):
                props = node.get("window_properties") or {}
                out.append({
                    "con_id": node["id"],
                    "xid": node["window"],
                    "workspace": workspace["name"],
                    "class": props.get("class") or "",
                    "title": props.get("title") or node.get("name") or "",
                })
    return out


def placeholders(tree) -> list[dict]:
    """i3 placeholder containers: a con whose `swallows` criteria are not empty.

    `pure` is True for an untouched placeholder (no children, no WM_CLASS of its
    own). Only those may be killed: killing a container that i3 folded a real
    window into would close that window too.
    """
    out = []
    for workspace in real_workspaces(tree):
        for node in walk_tree(workspace):
            if not node.get("swallows"):
                continue
            props = node.get("window_properties") or {}
            children = (node.get("nodes") or []) + (node.get("floating_nodes") or [])
            out.append({
                "con_id": node["id"],
                "workspace": workspace["name"],
                "criteria": node["swallows"],
                "pure": not children and not props.get("class"),
            })
    return out



def title_segments(title: str) -> set:
    """Meaningful chunks of a window title, used to tell same-app windows apart.

    `homeController.dart - earthquake_watch_flutter - Visual Studio Code` and
    `main.dart - earthquake_watch_flutter - Visual Studio Code` share the
    project folder, which survives a restart even when the open file changes.
    """
    parts = re.split(r"\s+-\s+|\s+—\s+|\s+·\s+", title or "")
    return {part.strip().lower() for part in parts if part.strip()}


def match_saved_window(win: dict, saved: list[dict], used: set) -> int | None:
    """Index of the saved window a live window belongs to (None when unsure)."""
    cls = win["class"].lower()
    # 1. exact class + title
    for index, record in enumerate(saved):
        if index not in used and cls == (record.get("class") or "").lower() \
                and win["title"] == record.get("title"):
            return index
    # 2. same class, best title overlap (folder / document names)
    live_segments = title_segments(win["title"])
    best, best_score = None, 0
    for index, record in enumerate(saved):
        if index in used or cls != (record.get("class") or "").lower():
            continue
        score = len(live_segments & title_segments(record.get("title") or ""))
        if score > best_score:
            best, best_score = index, score
    if best is not None and best_score >= 2:
        return best
    # 3. same class, but only when a single candidate is left
    remaining = [index for index, record in enumerate(saved)
                 if index not in used and (record.get("class") or "").lower() == cls]
    return remaining[0] if len(remaining) == 1 else None


def reconcile_once(session: dict, tree) -> int:
    """Move windows that came back on the wrong workspace; returns move count."""
    saved = session.get("windows") or []
    used: set = set()
    moves = 0
    for win in live_windows(tree):
        index = match_saved_window(win, saved, used)
        if index is None:
            continue
        used.add(index)
        record = saved[index]
        if win["workspace"] == record.get("workspace"):
            continue
        log("   move %-28s -> workspace %s" % (win["title"][:28], record.get("workspace")))
        i3_msg("[con_id=%d] move container to workspace %s"
               % (win["con_id"], i3_quote(record.get("workspace"))))
        moves += 1
    return moves


def wait_for_ambiguous_placeholder(workspace_name: str, classes: set,
                                   timeout: float = 12.0) -> bool:
    """Wait until one workspace's same-app placeholders have been used up.

    i3 matches a new window against *any* pending placeholder of its class, so
    before the layout of a later workspace that runs the same app is appended,
    the earlier workspace must have swallowed its windows. Otherwise the wrong
    window takes the wrong placeholder - that is what swapped the two VS Code
    windows between workspaces.
    """
    deadline = time.time() + timeout
    while True:
        tree = i3_tree()
        if tree:
            pending = [
                item for item in placeholders(tree)
                if item["workspace"] == workspace_name
                and any((criteria.get("class") or "").strip("^$").lower() in classes
                        for criteria in item["criteria"])
            ]
            if not pending:
                return True
        if time.time() >= deadline:
            return False
        time.sleep(0.25)


def saved_windows_present(session: dict, tree) -> tuple:
    """How many saved windows are back, plus the records still missing.

    Every live window can satisfy at most one record (the old version counted
    per class, which made two windows of the same app look like "all back" as
    soon as the first one appeared, and then dropped the second placeholder).
    """
    saved = session.get("windows") or []
    if not saved:
        return 0, []
    used: set = set()
    live = live_windows(tree)
    for win in live:
        index = match_saved_window(win, saved, used)
        if index is not None:
            used.add(index)
    missing = [record for index, record in enumerate(saved) if index not in used]
    return len(used), missing


def notify(summary: str, body: str) -> None:
    if shutil.which("notify-send"):
        run(["notify-send", "-a", "i3 session restore", summary, body])


def focus_target(session: dict) -> None:
    """Return to the workspace (and window) that was focused while saving."""
    target_ws = session.get("focused_workspace")
    if target_ws:
        i3_msg("workspace --no-auto-back-and-forth %s" % i3_quote(target_ws))
    window = session.get("focused_window") or {}
    cls = window.get("class")
    if not cls:
        return
    title = window.get("title")
    if title:
        res = i3_msg('[class="^%s$" title="^%s$"] focus' % (re.escape(cls), re.escape(title)))
        if i3_ok(res):
            return
    i3_msg('[class="^%s$"] focus' % re.escape(cls))


# --------------------------------------------------------------------------- #
# status / clear / CLI
# --------------------------------------------------------------------------- #
def show_status() -> int:
    session_file = STATE_DIR / "session.json"
    if not session_file.is_file():
        print("no saved session (%s)" % session_file)
        return 0
    try:
        session = json.loads(session_file.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print("!! cannot read %s: %s" % (session_file, exc))
        return 1
    if (STATE_DIR / "pending").exists():
        flag = "pending - will restore at the next login"
    elif (STATE_DIR / "pending.done").exists():
        flag = "already restored"
    else:
        flag = "none"
    print("saved session : %s" % session.get("saved_at"))
    print("state dir     : %s" % STATE_DIR)
    print("restore flag  : %s" % flag)
    print("workspaces    : %s" % ", ".join(
        "%s(%d win)" % (w.get("name"), len(w.get("windows") or []))
        for w in session.get("workspaces") or []))
    print("windows       : %d" % len(session.get("windows") or []))
    for record in session.get("windows") or []:
        print("   ws %-4s %-12s %-45s -> %s" % (
            record.get("workspace"), (record.get("class") or "")[:12],
            (record.get("title") or "")[:45],
            " ".join(record.get("cmd") or []) or "(no launch recipe)"))
    return 0


def clear_session(purge: bool = False) -> int:
    pending = STATE_DIR / "pending"
    if pending.exists():
        pending.unlink()
        print("pending restore flag removed - the next login starts clean")
    if purge:
        for name in ("session.json", "pending.running", "pending.done"):
            target = STATE_DIR / name
            if target.exists():
                target.unlink()
        for name in ("layouts", "kitty", "firefox", "chromium"):
            target = STATE_DIR / name
            if target.is_dir():
                shutil.rmtree(target, ignore_errors=True)
        print("saved session data deleted from %s" % STATE_DIR)
    return 0


def main(argv=None) -> int:
    global STATE_DIR
    parser = argparse.ArgumentParser(
        prog="session_lib.py",
        description="Save/restore the exact i3 session (workspaces, layout, apps).")
    parser.add_argument("command", choices=["save", "restore", "status", "clear"])
    parser.add_argument("--state-dir", help="override the state directory (for testing)")
    parser.add_argument("--dry-run", action="store_true", help="only show what would happen")
    parser.add_argument("--force", action="store_true", help="restore even without a pending save")
    parser.add_argument("--no-reconcile", action="store_true",
                        help="do not move windows between workspaces while restoring")
    parser.add_argument("--purge", action="store_true", help="with clear: delete the saved data too")
    args = parser.parse_args(argv)

    if args.state_dir:
        STATE_DIR = Path(args.state_dir)
    start_log("save.log" if args.command == "save" else "restore.log")

    # Deliberately broad: this runs from the power menu / login, where a
    # traceback is useless and a non-zero exit is what matters.
    try:
        if args.command == "save":
            return save_session(dry_run=args.dry_run)
        if args.command == "restore":
            return restore_session(dry_run=args.dry_run, force=args.force,
                                   reconcile=not args.no_reconcile)
        if args.command == "status":
            return show_status()
        return clear_session(purge=args.purge)
    except Exception as exc:  # noqa: BLE001
        log("!! %s failed: %s: %s" % (args.command, type(exc).__name__, exc))
        return 1


def restore_session(dry_run: bool = False, force: bool = False, reconcile: bool = True) -> int:
    """Rebuild the saved session: layouts, app launches, reconciliation, focus."""
    session_file = STATE_DIR / "session.json"
    if not session_file.is_file():
        log("no saved session at %s - nothing to restore" % session_file)
        return 0
    try:
        session = json.loads(session_file.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        log("!! cannot read %s: %s" % (session_file, exc))
        return 1

    pending = STATE_DIR / "pending"
    if not dry_run:
        if pending.exists():
            os.replace(pending, STATE_DIR / "pending.running")
        elif not force:
            log("no pending restore flag (this boot was not started from a saved session)")
            return 0

    saved: list[dict] = []
    records_by_ws: dict = {}
    class_counts: dict = {}
    for record in session.get("windows") or []:
        saved.append(record)
        records_by_ws.setdefault(record.get("workspace"), []).append(record)
        cls = (record.get("class") or "").lower()
        class_counts[cls] = class_counts.get(cls, 0) + 1
    # Applications living on more than one workspace of the same class make the
    # placeholders ambiguous (i3 only matches on class), so those get serialised.
    shared_classes = {cls for cls, count in class_counts.items() if count > 1}
    log("restoring session from %s: %d window(s) on %d workspace(s)"
        % (session.get("saved_at"), len(saved), len(session.get("workspaces") or [])))

    def workspace_classes(workspace: dict) -> set:
        return {(r.get("class") or "").lower()
                for r in records_by_ws.get(workspace.get("name"), [])}

    # 1. put browser session stores back before the browsers start
    app_state = session.get("app_state") or {}
    firefox_state = app_state.get("firefox")
    if firefox_state:
        if dry_run:
            log("would: prepare firefox profile %s" % firefox_state.get("profile"))
        else:
            log("   firefox: %s" % (firefox_restore(firefox_state) or "tabs restored from the saved store"))
    for group, info in (app_state.get("chromium") or {}).items():
        if dry_run:
            log("would: prepare %s" % group)
            continue
        log("   %s: %s" % (group, chromium_restore(info) or "session store restored"))

    # 2. rebuild every workspace (layout placeholders) and start its apps
    time.sleep(0.5)  # let i3, the bar and the wallpaper finish coming up
    launches = {entry["id"]: entry for entry in session.get("launches") or []}

    def launch_priority(workspace: dict) -> int:
        """Heavier apps first, so they are warm while the rest of the restore runs."""
        priority = 9
        for launch_id in workspace.get("launch_ids") or []:
            launch = launches.get(launch_id) or {}
            cmd = " ".join(launch.get("cmd") or [])
            kind = launch.get("kind")
            if kind in ("firefox", "chromium") or "flatpak" in cmd:
                priority = min(priority, 0)   # browsers and flatpak packages
            elif kind == "code":
                priority = min(priority, 1)   # Electron editors
            elif kind == "kitty":
                priority = min(priority, 2)
            elif kind == "filemanager":
                priority = min(priority, 3)
        return priority

    # Workspaces that share an app with a later workspace go last and are handled
    # one after another; the rest starts heavy-first. sorted() is stable, so the
    # saved order is kept inside each group.
    ordered = sorted(
        session.get("workspaces") or [],
        key=lambda ws: (bool(workspace_classes(ws) & shared_classes), launch_priority(ws)))

    started: list = []
    for position, workspace in enumerate(ordered):
        name = workspace.get("name") or ""
        later_classes: set = set()
        for other in ordered[position + 1:]:
            later_classes |= workspace_classes(other)
        ambiguous = workspace_classes(workspace) & later_classes
        layout = workspace.get("layout")
        if layout and Path(layout).is_file():
            if dry_run:
                log("would: workspace %s + append_layout %s" % (name, layout))
            else:
                i3_msg("workspace --no-auto-back-and-forth %s" % i3_quote(name))
                res = i3_msg("append_layout %s" % shlex.quote(layout), "command")
                if not i3_ok(res):
                    log("!! append_layout failed on workspace %s: %s"
                        % (name, (res.stdout or res.stderr).strip()))
        for launch_id in workspace.get("launch_ids") or []:
            launch = launches.get(launch_id) or {}
            cmd = launch.get("cmd") or []
            if not cmd:
                log("   ws %s: %s has no launch recipe (%s)"
                    % (name, launch_id, launch.get("note", "")))
                continue
            if dry_run:
                log("would: [ws %s] %s" % (name, " ".join(cmd)))
                continue
            log("   [ws %s] %s" % (name, " ".join(cmd)))
            proc = launch_process(cmd)
            if proc:
                started.append(proc)

        if ambiguous and not dry_run:
            if wait_for_ambiguous_placeholder(name, ambiguous):
                log("   ws %s: %s placed before moving on" % (name, "/".join(sorted(ambiguous))))
            else:
                log("   ws %s: %s window(s) still starting, carrying on" % (name, "/".join(sorted(ambiguous))))

    if dry_run:
        log("dry run: nothing changed")
        return 0

    # focus right away: waiting for the windows must not hold the desktop back
    focus_target(session)

    # 3. wait for the windows to come back and pull strays onto the right workspace
    deadline = time.time() + WAIT_SECONDS
    missing = saved
    while True:
        tree = i3_tree()
        if tree:
            if reconcile:
                reconcile_once(session, tree)
            found, missing = saved_windows_present(session, tree)
            if not missing:
                log("   all %d saved window(s) are back" % found)
                break
        if time.time() >= deadline:
            log("   %d window(s) still missing after %ds:" % (len(missing), WAIT_SECONDS))
            for record in missing:
                log("      ws %s %s - %s" % (record.get("workspace"), record.get("class"),
                                             (record.get("title") or "")[:50]))
            break
        if started and all(proc.poll() is not None for proc in started):
            time.sleep(2)
            tree = i3_tree()
            if tree and reconcile:
                reconcile_once(session, tree)
            _found, missing = saved_windows_present(session, tree)
            log("   launchers finished, %d window(s) missing" % len(missing))
            break
        time.sleep(1)

    # 4. very slow apps (flatpak, cold Electron) may still be starting: keep their
    # placeholders instead of dropping them, and keep watching in the background
    if missing:
        log("   keeping %d placeholder(s) while slow apps finish starting" % len(missing))
        late_deadline = time.time() + LATE_WATCH_SECONDS
        while time.time() < late_deadline:
            time.sleep(3)
            tree = i3_tree()
            if not tree:
                continue
            if reconcile:
                reconcile_once(session, tree)
            _found, still_missing = saved_windows_present(session, tree)
            if not still_missing:
                log("   late: everything is in place")
                missing = []
                break
            missing = still_missing

    # 5. remove placeholders whose app never showed up (they show as grey boxes)
    tree = i3_tree() or {}
    for item in placeholders(tree):
        criteria = (item["criteria"] or [{}])[0]
        if not item.get("pure"):
            # i3 folded a real window into this container: leave it alone.
            log("   keep container on ws %s (holds a window, class %s)"
                % (item["workspace"], criteria.get("class", "?")))
            continue
        log("   drop placeholder on ws %s (class %s)" % (item["workspace"], criteria.get("class", "?")))
        i3_msg("[con_id=%d] kill" % item["con_id"])

    # 6. wrap up (the focus was already restored right after the launches)
    if (STATE_DIR / "pending.running").exists():
        os.replace(STATE_DIR / "pending.running", STATE_DIR / "pending.done")
    log("restore finished")
    _, still_missing = saved_windows_present(session, i3_tree() or {})
    body = "%d window(s) reopened" % (len(saved) - len(still_missing))
    if still_missing:
        body += ", %d could not be restored" % len(still_missing)
    notify("Session restored", body)
    return 0



if __name__ == "__main__":
    sys.exit(main())
