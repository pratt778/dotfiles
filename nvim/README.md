# Neovim Config — prat

A minimal, Python-focused Neovim setup built on kickstart.nvim using the
built-in `vim.pack` plugin manager. Clean, fast, and lightweight for machine running EndeavourOS.

---

## Plugins

| Plugin | Purpose |
|---|---|
| `tokyonight.nvim` | Dark colorscheme |
| `which-key.nvim` | Keybind popup menu on Space |
| `telescope.nvim` | Fuzzy file/text search |
| `nvim-lspconfig` + `pyright` | Python LSP — autocomplete, errors |
| `mason.nvim` | LSP/tool installer |
| `blink.cmp` | Autocomplete engine |
| `nvim-treesitter` | Syntax highlighting |
| `gitsigns.nvim` | Git diff signs in gutter |
| `conform.nvim` | Code formatter |
| `todo-comments.nvim` | Highlights TODO/FIX/WARN |
| `mini.nvim` | Surround, AI, statusline, files, starter |
| `bufferline.nvim` | Tabs at the top |
| `snacks.nvim` | Indent guides, smooth scroll, notifications |
| `fidget.nvim` | LSP loading spinner |
| `LuaSnip` | Snippet engine |
| `nvim-autopairs` | Auto close brackets and quotes |

---

## Keybindings

### General
| Key | Action |
|---|---|
| `i` | Enter insert mode |
| `;;` | Exit insert mode |
| `Ctrl+S` | Save file |
| `Ctrl+A` | Select all |
| `Ctrl+C` | Copy |
| `Ctrl+V` | Paste |
| `Ctrl+Z` | Undo |
| `Ctrl+F` | Search in file |
| `Space+R` | Run Python file |
| `Space+K` | Kill running program |
| `Esc+Esc` | Close terminal |

### Navigation
| Key | Action |
|---|---|
| `Space+E` | Open file explorer |
| `Space+SF` | Find files (Telescope) |
| `Space+SG` | Live grep search |
| `Space+S.` | Recent files |
| `Shift+H` | Previous buffer/tab |
| `Shift+L` | Next buffer/tab |
| `Ctrl+H/J/K/L` | Move between splits |

### Editing
| Key | Action |
|---|---|
| `Alt+Up/Down` | Move line up/down |
| `Alt+Shift+Down` | Duplicate line |
| `> / <` (visual) | Indent / unindent |
| `Space+F` | Format buffer |
| `Space+R` | Search and replace word under cursor |
| `/word` then `n/N` | Search and cycle matches |
| `:%s/old/new/g` | Find and replace all |

### LSP
| Key | Action |
|---|---|
| `grn` | Rename variable |
| `gra` | Code action |
| `grd` | Go to definition |
| `grr` | Go to references |
| `Space+SD` | Search diagnostics |

---

## Setup

### Requirements
```bash
sudo pacman -S neovim tree-sitter-cli python-lsp-server
pip install python-lsp-server[all] --break-system-packages
```

### Install
```bash
# Remove old config if any
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim

# Clone kickstart
git clone https://github.com/nvim-lua/kickstart.nvim.git ~/.config/nvim

# Open nvim — plugins install automatically
nvim

# Install Python LSP inside nvim
:MasonInstall pyright
```

### Python LSP
Make sure `pyright` is uncommented in `init.lua`:
```lua
local servers = {
  pyright = {},
  lua_ls = { ... },
}
```

---

## Dashboard
Opens automatically when you run `nvim` without a file. Built with `mini.starter`.

---

## File Structure
```
~/.config/nvim/
└── init.lua        # single file config, everything is here
```

---
