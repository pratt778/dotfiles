# ⚡ PRAT's Neovim Cheatsheet (Keyboard-First Edition)

> **Philosophy**: Zero-mouse workflow. Keep your hands on the home row.  
> **Leader Key** = `Space` | **Control Key** = `Ctrl` | **Exit Insert Mode** = `;;`  
> All shortcuts are verified against your live Neovim configuration.

---

## 📑 Table of Contents
1. [⚡ Daily Essentials (Top 10 Keyboard Keys)](#-daily-essentials-top-10-keyboard-keys)
2. [⌨️ Core Editing & Clipboard](#️-core-editing--clipboard)
3. [🔍 Search, Find & Replace](#-search-find--replace)
4. [📂 Files, Tabs & Neo-tree Sidebar](#-files-tabs--neo-tree-sidebar)
5. [🧠 LSP, Definitions & Diagnostics (The `g` Keys)](#-lsp-definitions--diagnostics-the-g-keys)
6. [🐛 Debugging & Breakpoints (DAP)](#-debugging--breakpoints-dap)
7. [🖥️ Terminal & Sidecars](#️-terminal--sidecars)
8. [📱 Flutter Guide & Daily Workflow](#-flutter-guide--daily-workflow)
9. [🦀 Rust Guide & Daily Workflow](#-rust-guide--daily-workflow)
10. [🖱️ Optional Mouse Shortcuts (Convenience Only)](#️-optional-mouse-shortcuts-convenience-only)
11. [🚑 Troubleshooting & FAQ](#-troubleshooting--faq)

---

## ⚡ Daily Essentials (Top 10 Keyboard Keys)

The core keyboard shortcuts you use 90% of the time without ever touching a mouse:

| Shortcut | Action | Description |
|---|---|---|
| `Ctrl + s` | **Save File** | Works in Normal, Insert, and Visual modes |
| **`gd`** (or `F12`) | **Go to Definition** | Cursor on any class/function/variable → jump straight inside! |
| **`<C-t>`** (or `Alt + Left`) | **Jump Back** | Return to where you were before pressing `gd` |
| `<leader><Tab>` / `<BS>` | **Previous File** | Instant flip between last 2 files (Space+Tab or Backspace) |
| `Ctrl + o` | **Quick Open File** | Fuzzy file search across project (VSCode `Ctrl+P`) |
| `Ctrl + f` | **Find in File** | Search inside current buffer (`n` = next, `N` = prev) |
| `Ctrl + h` (or `<leader>rp`) | **Find & Replace** | Interactive replace with confirmation (`y`/`n`/`a`/`q`) |
| `Ctrl + j` (or `Ctrl + ` `) | **Toggle Terminal** | Opens/closes popup terminal from anywhere |
| `\` | **Toggle Sidebar** | Opens/closes Neo-tree without stealing focus from code |
| `<leader>ee` | **Focus Sidebar** | Jumps cursor straight into the Neo-tree file tree |
| `;;` | **Exit Insert Mode** | Return to Normal mode instantly |

---

## ⌨️ Core Editing & Clipboard

Standard editing shortcuts that keep you fast on the keyboard across Normal, Insert, and Visual modes:

| Shortcut | Mode | Action |
|---|---|---|
| `Ctrl + s` | Normal / Insert / Visual | **Save buffer** |
| `Ctrl + z` | Normal / Insert / Visual | **Undo** |
| `Ctrl + r` or `Ctrl + Shift + z` | Normal / Insert / Visual | **Redo** |
| `Ctrl + a` | Normal / Insert / Visual | **Select All** |
| `Ctrl + c` | Normal / Visual | **Copy** (line or selection) to system clipboard |
| `Ctrl + x` | Normal / Insert / Visual | **Cut** (line or selection) to system clipboard |
| `Ctrl + v` | Normal / Insert / Visual | **Paste** from system clipboard |
| `Ctrl + Backspace` | Insert | **Delete whole word** backwards |
| `Ctrl + u` / `Ctrl + d` | Normal | **Scroll half-page** up / down (cursor stays centered) |
| `gcc` | Normal | **Toggle comment** on current line |
| `gc` | Visual | **Toggle comment** on selected lines |

---

## 🔍 Search, Find & Replace

### 1. In Current File
| Shortcut | Action |
|---|---|
| `Ctrl + f` | **Find in file** (type query; press `n` for next match, `N` for previous) |
| `<leader>/` | **Fuzzy lines search** (interactive dropdown filtering current file) |
| `*` | Search the word currently under cursor forward |
| `Ctrl + h` or `<leader>rp` | **Find & Replace** with step-by-step confirmation (`y` replace, `n` skip, `a` all) |
| `Ctrl + Shift + h` or `<leader>ra` | **Replace ALL occurrences** in current file |
| *Visual selection* + `Ctrl + h` | Replace only within selected lines |

### 2. Across Entire Project
| Shortcut | Action |
|---|---|
| `Ctrl + o` | **Fuzzy file picker** by name (VSCode `Ctrl+P`) |
| `Ctrl + Shift + o` | **Recent files history** |
| `<leader><leader>` | **List open buffers/tabs** |
| `<leader>sg` | **Live Grep project** (VSCode `Ctrl+Shift+F` — ripgrep searches all code) |
| `<leader>sw` | **Search word under cursor** across all project files |
| `<leader>pr` | **Project-wide Replace** (VSCode `Ctrl+Shift+H`):<br>1. Type query → matches appear in quickfix list<br>2. Type replacement → updates all files<br>3. Prompts to save all modified files automatically |

---

## 📂 Files, Tabs & Neo-tree Sidebar

### 1. Neo-tree Sidebar (100% Keyboard)
> **`\` toggles** the sidebar without moving your cursor from your code.  
> **`<leader>ee` focuses** the sidebar so you can navigate files with keys.

| Shortcut | Where | Action |
|---|---|---|
| `\` | Anywhere | **Toggle sidebar** open / close (cursor stays in code) |
| `<leader>ee` | Anywhere | **Focus sidebar** (jumps cursor straight into tree) |
| `<C-h>` / `<C-l>` | Anywhere | Move window focus between tree (left) and code (right) |
| `q` or `<Esc>` | Inside Tree | **Close sidebar** |
| `Enter` or `l` | Inside Tree | Open file / expand folder |
| `h` | Inside Tree | Collapse folder / jump to parent |
| `<BS>` | Inside Tree | Go up to parent directory |
| `H` | Inside Tree | Toggle hidden dotfiles (`.env`, `.gitignore`, etc.) |
| `/` | Inside Tree | Fuzzy filter files in tree |

### 2. Creating & Managing Files with Keys
| Inside Neo-tree | Action |
|---|---|
| `a` then `name.dart` | **Create File** (type `models/user.dart` to auto-create parent folders!) |
| `a` then `foldername/` | **Create Folder** (must end with `/`, e.g. `bloc/` or `widgets/`) |
| `r` | **Rename** file or folder |
| `d` | **Delete** file or folder (confirms before deleting) |

| Anywhere in Neovim | Action |
|---|---|
| **`Ctrl + n`** | **Instant New File**: pre-fills current folder (or `lib/` in Flutter, `src/` in Rust). Type filename → parent folders + file created on disk immediately! |
| `Ctrl + e` | Alternative `mini.files` explorer popup |

### 3. Buffers, Tabs & Sessions
| Shortcut | Action |
|---|---|
| **`<leader><Tab>`** | **Toggle Previous File** (Space then Tab — instant switch between 2 files) |
| **`<BS>`** | **Toggle Previous File** (Single tap on Backspace in Normal mode!) |
| **`<leader>a`** | **Toggle Alternate File** (Space then a) |
| `Shift + l` / `Shift + h` | **Next / Previous tab** in tabline (linear cycling) |
| `<leader>bd` | **Close current buffer** |
| `<leader>br` / `<leader>bl` | Close buffers to the right / left |
| `<leader>bp` | Toggle pin buffer tab |
| `<leader>qs` | **Restore Project Session** (restore all tabs & layout) |
| `<leader>ql` | **Restore Last Session** |
| `<leader>qd` | Don't save current session |

### 4. Saving & Quitting
| Shortcut / Command | Action | Description |
|---|---|---|
| `Ctrl + s` | **Save File** | Saves current file (Normal, Insert, Visual) |
| **`<leader>qq`** or `<leader>qa` | **Save All & Quit** | Writes all modified files and exits Neovim cleanly |
| **`<leader>q!`** | **Force Quit** | Exits Neovim discarding unsaved changes |
| `:wqa` | Command | **W**rite **Q**uit **A**ll — use this when multiple files are open (prevents E37 / E162) |
| `:wa` | Command | Write/save all open files |
| `:qa!` | Command | Force quit all without saving |
| `ZZ` | Normal mode | Quick save current file and close |

---

## 🧠 LSP, Definitions & Diagnostics (The `g` Keys)

> [!TIP]
> **Keyboard Definition (`gd` vs `gg`)**:
> - **`gd`** = **G**o to **D**efinition. Place your cursor on any class name, widget, or function and press **`gd`** to jump straight into it!
> - *(Note: In Vim, `gg` jumps to line 1 of the file, while `gd` jumps to the definition).*
> - **`<C-t>`** or **`Alt + Left`** pops your jump stack and brings you right back where you started.

### 1. Navigation & Refactoring
| Shortcut | Action | Description |
|---|---|---|
| **`gd`** or `F12` | **Go to Definition** | Jump straight inside class/function/variable declaration |
| **`<C-t>`** or `Alt + Left` | **Jump Back** | Return to previous location before jumping |
| `Alt + Right` | **Jump Forward** | Re-jump forward to the definition |
| **`gr`** or `Shift + F12` | **Find All References** | Search all places where this class/function is used |
| **`gi`** or `gI` / `Ctrl + F12` | **Go to Implementation** | Jump to interface/abstract class implementation (lowercase `gi` works!) |
| **`K`** | **Hover Documentation** | View type signatures, documentation, and parameter info |
| `F2` or `<leader>rn` | **Rename Symbol** | Safe symbol rename across the entire project |
| `Ctrl + .` or `<leader>ca` | **Quick Fix / Code Actions** | Auto-import, wrap widgets, Clippy fixes |
| `<leader>th` | **Toggle Inlay Hints** | Show inferred types & param names inline |
| `<leader>ft` | **Format buffer** | Runs `dart format`, `rustfmt`, etc. |

### 2. Diagnostics & Error Indicators
- **Live Insert Mode Checking**: Diagnostics update live as you type without waiting to exit insert mode (`;;` / `<Esc>`).
- **Sidebar (Neo-tree)**: Files and folders with errors/warnings show ` ` (error) or ` ` (warning) badges.
- **Top Tabs (Bufferline)**: Tab headers show real-time error counts (e.g. ` 2  1`).
- **Trouble Panel (`<leader>xx`)**: Opens bottom list of all project errors & warnings (VSCode Problems tab). Jump to any error with `Enter`.
- **Inline Jumping**: `]d` jumps to next diagnostic in file, `[d` jumps to previous.

### 3. Autocomplete (VSCode Rules)
| Key | Action |
|---|---|
| `Tab` | **Accept suggestion** / jump to next snippet placeholder |
| `Enter` | Newline — never accidentally forces a suggestion |
| `Ctrl + j` / `Ctrl + k` | Next / previous suggestion |
| `Shift + Tab` | Previous suggestion / snippet jump back |
| `Ctrl + Space` | Trigger suggestions popup manually |

---

## 🐛 Debugging & Breakpoints (DAP)

> [!TIP]
> **VSCode Debug Bar Equivalents**:
> - **Play / Continue (▶)**: **`F5`** (unpauses execution)
> - **Step Over (↷)**: **`F2`** | **Step Into (⇲)**: **`F1`** | **Step Out (⇱)**: **`F3`**
> - **Inspect Variables & Call Stack**: **`F7`** (Scopes + Stack frames + Console)
> - **View Error Details**: **`<leader>fd`** (opens Flutter logs where red error stack trace is printed)
> - **Stop App (⏹)**: **`<leader>fl` → 🛑 Quit App** (or `:FlutterQuit`)

| Shortcut | Action |
|---|---|
| **`<leader>b`** or `<leader>db` | **Toggle Breakpoint** on current line |
| **`<leader>B`** | **Conditional Breakpoint** (prompts for expression, e.g. `count > 10`) |
| **`F5`** or `Alt + p` | **Start / Continue Debugging** (Play ▶) |
| **`F1`** | **Step Into** (enter function/method) |
| **`F2`** | **Step Over** (execute next line) |
| **`F3`** | **Step Out** (finish current function and return) |
| **`F7`** | **Toggle Debug UI** (Variables/Scopes + Call Stack + Console) |
| `<leader>dc` | Floating Debug Console (`q` to dismiss) |
| `<leader>dr` | Floating REPL (evaluate live expressions while paused) |

---

## 🖥️ Terminal & Sidecars

| Shortcut | Action |
|---|---|
| **`Ctrl + j`** (or `Ctrl + ` `) | **Open / Close popup terminal** (works in Normal, Insert, & inside terminal) |
| `<leader>tt` | Alternative toggle (Space → t → t) |
| `Esc Esc` | Leave terminal typing mode → Normal mode (allows scrolling and copying text) |
| Type `exit` | Permanently terminate the shell and close window |
| `<leader>lg` | Open **LazyGit** full screen (`q` to exit) |
| `<leader>gg` / `gl` | Gemini interactive CLI session / resume latest |

---

## 📱 Flutter Guide & Daily Workflow

### Flutter Shortcut Reference
| Shortcut | Action | Description |
|---|---|---|
| `Alt + o` | **Save + Hot Reload** | Works from Normal and Insert mode |
| `Alt + e` | **Hot Restart** | Restarts app state (Normal and Insert mode) |
| `Alt + p` or `F5` | **Run with Debugger** | Breakpoints will trigger and pause execution |
| `<leader>fl` | **Flutter Master Menu** | Pick Device, Emulators, Reload, Restart, DevTools, Quit |
| `<leader>fo` | **Widget Tree Outline** | Toggles in-editor Widget Tree panel sidebar |
| `<leader>fw` | **Browser DevTools** | Opens Dart DevTools & Widget Inspector in browser |
| `<leader>fv` | **Visual Debug Guidelines** | Toggles paint baselines & margin boxes on screen |
| `<leader>fd` | **Toggle Flutter Logs** | Opens logs (errors in red!). Press `Enter` or click on any file:line to jump straight to it! |
| `<leader>fs` | **Flutter App Status** | Shows building / running state and elapsed time |
| `Ctrl + .` / `<leader>ca` | **Widget Refactoring** | Wrap with Padding/Center/Column/Row/Widget, Extract Widget |
| **`<leader>cb`** | **Wrap with BLoC** | Wrap with MultiBlocProvider, BlocProvider, BlocBuilder, BlocConsumer, BlocListener... (supports smart conversion: e.g. turning `BlocProvider` → `MultiBlocProvider` cleanly without duplicating `child:`) |
| **`<leader><Tab>`** / **`<BS>`** | **Toggle Previous Screen** | Instant flip between last 2 files (e.g. task_board ↔ task_detail) |

### Daily Flutter Workflow (Step-by-Step)
1. **Launch Project**: `nvim .` in your Flutter project folder.
2. **Open / Focus Files**:
   - `Ctrl + o` to fuzzy open `main.dart` or any screen.
   - `\` to toggle sidebar, or `<leader>ee` to jump focus directly into the tree.
3. **Select Target Device**:
   - Press `<leader>fl` → select `📱 Select Device` or `🎮 Emulators`.
4. **Start the App**:
   - Press `<leader>fl` → `▶ Run App` (or `Alt + p` for debugger).
   - Statusline badge indicates progress: `⏳ building…` → `🟢 running`.
   - Press `<leader>fd` anytime to view device console logs.
5. **Live Coding (Keyboard-First)**:
   - Put cursor on a widget/class and press **`gd`** to jump into its definition.
   - Press **`<C-t>`** to jump straight back.
   - Press **`Ctrl + .`** on any widget to wrap or extract it.
   - Make edits → press **`Alt + o`** to Hot Reload instantly.
   - For state/initialization changes → press **`Alt + e`** to Hot Restart.
6. **Inspecting Widgets**:
   - Press **`<leader>fo`** for the in-editor Widget Outline tree.
   - Press **`<leader>fw`** to inspect widgets in the browser DevTools inspector.
7. **Debugging**:
   - Set breakpoints with `<leader>b`.
   - When paused, press `F1` (into), `F2` (over), `F3` (out), or `F7` for variable scopes.
8. **Stopping**:
   - Press `<leader>fl` → `🛑 Quit App` (or `:FlutterQuit`).

---

## 🦀 Rust Guide & Daily Workflow

Full Rust IDE support powered by `rust-analyzer`, `rustfmt`, `clippy`, and `codelldb`.

### Rust Shortcut Reference
| Shortcut | Action | Description |
|---|---|---|
| `Ctrl + s` | **Save + Format + Clippy** | Runs `rustfmt` and checks via `cargo clippy` |
| `<leader>th` | **Toggle Inlay Hints** | Shows variable types, parameter names, chained call types |
| `Ctrl + .` / `<leader>ca` | **Clippy Auto-Fix** | Apply compiler recommendations and imports |
| `gd` | **Go to Definition** | Jump into struct, trait, or function definition |
| `<C-t>` or `Alt + Left` | **Jump Back** | Return to previous position |
| `F2` | **Rename Symbol** | Compile-safe workspace-wide renaming |
| `K` | **Type / Docs Hover** | Inspect types and documentation comments |
| `F5` | **Debug Rust Binary** | Debug via `codelldb` (set breakpoints with `<leader>b`) |
| `<leader>xx` | **Trouble Diagnostics** | View all Clippy and rustc warnings/errors |

### Daily Rust Workflow (Step-by-Step)
1. `nvim .` in your Rust crate directory.
2. Press `Ctrl + n` to create a new module (pre-fills `src/`).
3. Write code with autocompletion and inlay hints (`<leader>th`).
4. Jump into structs/traits with `gd`, and jump back with `<C-t>`.
5. Save with `Ctrl + s` (auto-formats with `rustfmt` + runs Clippy).
6. Press `Ctrl + .` on warnings to auto-fix them.
7. Press `Ctrl + ` ` to toggle the popup terminal and run `cargo test` or `cargo run`.
8. Set breakpoints with `<leader>b` and debug binaries with `F5`.

---

## 🖱️ Optional Mouse Shortcuts (Convenience Only)

For times when you happen to have your hand on the mouse:

| Action | Shortcut |
|---|---|
| **Go to Definition** | `Ctrl + Left Click` on any class, method, or variable |
| **Move Cursor** | `Left Click` on any line or word |
| **Select Text** | `Left Click + Drag` |
| **Scroll Viewport** | `Mouse Wheel` up / down |

---

## 🚑 Troubleshooting & FAQ

| Problem | Cause | How to Fix |
|---|---|---|
| **Swap file popup on opening a file** (`NEWER than swap file!`) | An old session crashed or terminal was closed abruptly | Press **`d`** to delete the old swap file. To clean all stale swap files at once, run `rm -f ~/.local/state/nvim/swap/*` in your terminal. |
| **`Ctrl + ` ` doesn't toggle terminal** | Your terminal emulator is intercepting the backtick key | Use **`<leader>tt`** (Space → t → t) instead. |
| **Terminal cursor stuck in typing mode** | Terminal buffer is in interactive shell mode | Press **`Esc Esc`** (two quick escapes) to switch to normal mode, then navigate or close with `:q`. Type **`exit`** to terminate. |
| **Flutter Hot Reload does nothing** | Cursor is not in a `.dart` buffer or app is stopped | Make sure app is running (`🟢 running` in statusline) and your cursor is in a `.dart` file. Use **`Alt + o`**. |
| **Flutter build consumes too much RAM** | Gradle running unlimited daemon workers | Configured via `~/.gradle/gradle.properties` (2G heap, 1 worker). Run `cd android && ./gradlew --stop` if stuck. |
| **Empty DAP debug windows appear** | Leftover windows from an earlier session | Press **`F7`** to dismiss them. They now open strictly on demand. |
| **`nvim .` opens stale or extra blank windows** | Restored session has old layout | Close extra windows with `<leader>bd`, open desired files, and quit cleanly once (`:qa`). |
