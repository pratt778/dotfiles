# NVIM config

Config for my neovim workflow. This setup is a custom build optimized for speed, aesthetics, and professional development (specifically Flutter/Dart and Lua).

## 🚀 Key Features
- **Plugin Manager:** [lazy.nvim](https://github.com/folke/lazy.nvim)
- **UI & Aesthetics:** TokyoNight theme, Snacks.nvim for dashboard/indents, and Bufferline.
- **Development:** Full LSP support via Mason, Autocompletion (nvim-cmp), and Formatting (Conform).
- **Navigation:** Telescope for fuzzy finding and Flash.nvim for "teleportation."
- **Debugging:** Integrated debugger with DAP and specialized Flutter tools.

## 🔌 Plugin Breakdown

### 🛠️ Core Infrastructure & UI
- **lazy.nvim**: The core plugin manager that keeps startup times ultra-fast.
- **snacks.nvim**: A multi-tool providing the dashboard, indent lines, smooth scrolling, and notifications.
- **which-key.nvim**: Interactive cheat sheet for all your keybindings.
- **tokyonight.nvim**: The primary high-contrast, eye-friendly colorscheme.
- **dressing.nvim**: Modernizes the look of all default Neovim inputs and selection menus.

### 🧠 Intelligence (LSP & Autocomplete)
- **nvim-lspconfig**: Bridge to Language Servers for IDE-like features.
- **mason.nvim**: In-editor package manager for LSPs, formatters, and debuggers.
- **nvim-cmp**: High-performance completion engine with multiple sources (LSP, path, buffer).
- **lspkind.nvim**: Adds intuitive icons to the completion menu.
- **lazydev.nvim**: Specialized intelligence for writing Neovim/Lua configurations.
- **fidget.nvim**: Visual status updates for LSP background tasks.

### 📝 Editing & Coding Efficiency
- **nvim-treesitter**: Advanced code parsing for superior syntax highlighting and structural awareness.
- **mini.surround / mini.ai**: Quick manipulation of surrounding characters and intelligent text objects.
- **nvim-autopairs**: Automatic bracket and quote completion.
- **conform.nvim**: Powerful auto-formatting on save.
- **nvim-lint**: Real-time code analysis and linting.
- **todo-comments.nvim**: Highlights keywords like `TODO` and `FIXME`.
- **LuaSnip**: Robust snippet engine for rapid boilerplate expansion.

### 🔍 Navigation & Search
- **telescope.nvim**: The central hub for searching files, text, and Git history.
- **flash.nvim**: Lightning-fast cursor movement to any visible text.
- **mini.files**: Modern, text-based file explorer for rapid file system manipulation.
- **vim-tmux-navigator**: Seamless switching between Neovim and Tmux windows.

### 📂 Project Management & Git
- **bufferline.nvim**: Visual tab bar for managing open buffers.
- **mini.statusline**: Minimalist status bar at the bottom.
- **gitsigns.nvim**: Visual indicators for Git changes directly in the sign column.
- **persistence.nvim**: Automated session management to pick up where you left off.
- **trouble.nvim**: A beautiful project-wide view for errors and diagnostics.

### 🐛 Debugging & Specialized Tools
- **nvim-dap / nvim-dap-ui**: Full debugger integration with a professional UI.
- **flutter-tools.nvim**: Deep integration for Flutter development (Hot Reload, DevTools).
- **obsidian.nvim**: Tools for managing personal knowledge bases within Neovim.

---

## Based on KICKSTART.NVIM
- [THE OLD README](README_OLD.md)
