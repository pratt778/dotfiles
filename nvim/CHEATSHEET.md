# ✅ PRAT's REAL Neovim Cheatsheet (VSCode edition)

> Every key verified against your actual config. Leader = `Space`. Restart nvim after config changes.

## 🖱️ VSCode-style Basics (Normal + Insert + Visual)

| Shortcut | Action |
|---|---|
| `<C-s>` | Save |
| `<C-a>` | Select All |
| `<C-c>` | Copy (line / selection) |
| `<C-x>` | Cut (line / selection) |
| `<C-v>` | Paste |
| `<C-z>` | Undo |
| `<C-r>` / `<C-S-z>` | Redo |
| `<C-f>` | Find in file |
| `<C-h>` | Find & Replace — confirm each match (y/n/a/q) |
| `<C-S-h>` | **Replace All** (also `<leader>ra`) |
| `<C-u>` / `<C-d>` | Half-page scroll (cursor centered) |
| `;;` | Exit Insert Mode |

## 📝 Files & Tabs

| Shortcut | Action |
|---|---|
| `<C-n>` | **New file** — pre-fills the current file's folder (or `lib/` in Flutter), creates folders + the real file on disk instantly, warns if the path is a folder |
| `<C-o>` | Open file (fuzzy) — like VSCode `Ctrl+P` |
| `<C-S-o>` | Recent files |
| `<C-e>` | mini.files explorer |
| `<C-Tab>` / `<C-S-Tab>` | Next / previous file (Normal + Insert) |
| `<S-l>` / `<S-h>` | Next / previous file (always works) |
| `<leader>bd` | Close current file |

## 📂 Sidebar (Neo-tree)

> **`\` is a true toggle from any window** — press it in your code to open the
> sidebar (your cursor stays in the code, the tree appears on the left), press it
> again to close it. It also works while you are inside the tree window.

### 🚀 Starting nvim (pick up where you left off)

| You type | What happens |
|---|---|
| `nvim .` (project you've worked in) | **Your last file opens automatically** + tree as a left sidebar. Zero `l`/`Enter` needed |
| `nvim .` (brand-new project) | No saved session → tree opens full-window so you can browse |
| `nvim lib/main.dart` | Opens that file directly |
| `nvim` (no args) | Empty buffer / dashboard, tree on `\` |

Sessions save automatically when you quit nvim cleanly, per project folder.

### Keys inside the tree

| Key | Action |
|---|---|
| `l` | Into folder / open file |
| `h` | Collapse / go back |
| `Enter` | Open file (one press) |
| `<BS>` | Up to parent folder |
| `a` | New file/folder (end name with `/` for folder) |
| `r` / `d` | Rename / Delete |
| `H` | Toggle dotfiles |
| `/` | Fuzzy filter the tree |
| `\` | Close the sidebar (toggle) |

## 📂 mini.files explorer (`<C-e>` or `<leader>em`)

Same controls as Neo-tree: `l` in, `h` out, **`q` / `Esc` / `H` to close**.
Plus: `a` create, `D` delete, `r` rename, `g.` dotfiles, `gc` set cwd, `<C-w>v`/`<C-w>s` open in split.

## ⌨️ Autocomplete (VSCode rules)

| Key | Action |
|---|---|
| **`Tab`** | **Accept suggestion** / jump to next snippet placeholder |
| **`Enter`** | Newline — never force-accepts a suggestion you didn't pick |
| `<C-j>` / `<C-k>` | Next / previous suggestion |
| `<S-Tab>` | Previous suggestion / snippet jump back |
| `<C-Space>` | Trigger suggestions manually |
| `<C-BS>` | Delete whole word (insert mode) |

## 📱 Flutter / Dart (active once a `.dart` file is open)

| Shortcut | Action |
|---|---|
| **`Alt+o`** | **Save + Hot Reload** (works from insert mode too) |
| **`Alt+e`** | **Hot Restart** |
| **`Alt+p`** | **Run with Debugger** (breakpoints active) |
| `<leader>fs` | **App status** — building / running / stopped + how long |
| `<leader>fl` | Flutter Master Menu (▶ Run, ⚡ Reload, 🔄 Restart, 📱 Device, 📋 Logs, 🌐 DevTools, 🛑 Quit…) |
| `<leader>fd` | Toggle Flutter Logs |
| `<leader>fl` → 🛑 Quit App | Stop the running app |
| `<leader>ca` / `<C-.>` | Code Actions / Quick Fix |
| `<leader>xx` | All project errors & warnings (Trouble) |

Direct commands: `FlutterRun`, `FlutterReload`, `FlutterRestart`, `FlutterDevices`, `FlutterQuit`.

### 🚦 Run indicator (statusline)

While the app is up, the statusline shows a badge: `⏳ building…` → `🟢 running` → (gone when stopped).
Notifications fire on every state change, and `<leader>fs` prints details.
If stuck on `⏳ building…` for minutes, the build is genuinely hung — check `<leader>fd` logs or quit and re-run.

## 🐛 Debugging (DAP) — no debug windows appear until you ask

| Shortcut | Action |
|---|---|
| `F5` / `Alt+p` | Start / Continue debugging |
| `<leader>b` | Toggle Breakpoint |
| `<leader>B` | Conditional Breakpoint |
| `F7` | Toggle compact debug strip (console + scopes, bottom) |
| `<leader>dc` | Debug console as floating window (`q` to dismiss) |
| `<leader>dr` | REPL as floating window (evaluate expressions while paused) |
| `F1` / `F2` / `F3` | Step Into / Over / Out |

## 🧠 LSP (VSCode parity)

| Shortcut | Action |
|---|---|
| `gd` / `F12` | Go To Definition |
| `gr` / `<S-F12>` | Find References |
| `F2` | Rename Symbol |
| `<C-.>` | Quick Fix |
| `K` | Hover Docs |

## 🔍 Search & Replace

### Inside the current file

| Shortcut | Action |
|---|---|
| `<C-f>` | Find in file |
| `<C-h>` | Find & Replace (confirm each match: y/n/a/q) |
| `<C-S-h>` | Replace **All** in file (also `<leader>ra`) |
| `*` | Find word under cursor (then `<C-S-h>` to replace all of them) |
| Select text first + `<C-h>` | Replace only within selection |

### Across the whole project

| Shortcut | Action |
|---|---|
| **`<leader>pr`** | **Project-wide Replace** (VSCode `Ctrl+Shift+H`): greps all files → shows matches in quickfix window → type replacement → replaces everywhere → offers to save all files |
| `<leader>sg` | Search text across project (browse only) |
| `<leader>sw` | Search word under cursor across project |
| `<leader>s.` | Recent files |
| `<leader><leader>` | Open buffers |

> Safety tip: for renaming variables/functions, prefer `F2` (Rename Symbol) — it's compile-safe across the project. `<leader>pr` is for plain text.

## 🤖 Gemini (terminal)

| Shortcut | Action |
|---|---|
| `<leader>gg` | New session |
| `<leader>gl` | Resume latest |
| `<leader>gr` | Browse sessions |

## 🖥️ Terminal

| Shortcut | Action |
|---|---|
| **`<C-``>`** (Ctrl + backtick) | **Open / close terminal** — same key toggles, works in Normal, Insert and even from inside the terminal |
| `<leader>tt` | Same toggle (if your terminal eats Ctrl+backtick) |
| `Esc` `Esc` | Leave terminal typing mode → Normal mode (then scroll/copy freely) |
| type `exit` | Permanently close the shell |

| Other terminals | Key |
|---|---|
| `<leader>gg` / `gl` / `gr` | Gemini sessions |
| `<leader>lg` | LazyGit |

## 🪟 Misc

| Shortcut | Action |
|---|---|
| `<C-h/j/k/l>` | Move between splits |
| `<leader>lg` | LazyGit |
| `<leader>ti` / `<leader>th` | Indent guides / Inlay hints |
| `<leader>qs` / `<leader>ql` | Restore session / last session |
| `<leader>ft` | Format file |
| `gcc` | Toggle comment |

## 🔥 Daily Flutter flow

```
nvim .                     → your last file opens + sidebar (no drilling needed)
write code                 → Tab accepts suggestions, <C-BS> deletes words
Alt+o                      → save + hot reload
Alt+e                      → hot restart (state broke)
Alt+p / F5 + <leader>b     → debug with breakpoints
F7 / <leader>dc            → inspect variables / console
<leader>fl → 🛑 Quit App   → done
```

## 🚑 Troubleshooting

| Problem | Fix |
|---|---|
| "readonly, ! to override" on save/quit | Usually a stale swap file from a crash — `:wq!` to force once, and delete the swap when prompted next time |
| Swap recovery prompt when opening | Old crash leftovers — choose **Delete** if you don't need unsaved work |
| `Ctrl+Tab` / `Ctrl+Backspace` do nothing | Terminal eats the combo — use `S-l`/`S-h` for tabs instead |
| "Hot reload only works in a .dart file" | Cursor must be in a `.dart` buffer **and** the app must be running |
| Weird empty DAP windows everywhere | Press `F7` to close; they only open on demand now |
| Build eats all RAM (htop 100%) | Fixed via gradle.properties (2G heap, 1 worker). Extra relief: `cd android && ./gradlew --stop` |
| `nvim .` opens a blank/stale file | The saved session is old. Open the file you want once and quit cleanly — that becomes the restored one. Use `<leader>qd` to stop saving the current session |
| Extra blank windows after `nvim .` | Leftovers from an old session layout — close with `<leader>bd` or just quit cleanly once and they're gone |
