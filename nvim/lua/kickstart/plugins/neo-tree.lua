-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  lazy = false, -- must load at startup so `nvim .` directory hijack works
  priority = 1000,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  cmd = 'Neotree',
  keys = {
    {
      '\\',
      function()
        -- Deterministic toggle: close the tree if it's open, otherwise open
        -- it as a left sidebar without stealing focus from your code.
        local tree_win = nil
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):find('neo%-tree') then
            tree_win = w
            break
          end
        end
        if tree_win then
          pcall(vim.api.nvim_win_close, tree_win, true)
          return
        end
        local prev = vim.api.nvim_get_current_win()
        require('neo-tree.command').execute {
          action = 'show',
          source = 'filesystem',
          position = 'left',
          dir = vim.fn.getcwd(),
        }
        if vim.api.nvim_win_is_valid(prev) and vim.api.nvim_get_current_win() ~= prev then
          pcall(vim.api.nvim_set_current_win, prev)
        end
      end,
      desc = 'NeoTree toggle sidebar',
      silent = true,
    },
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = 'rounded',
    default_component_configs = {
      -- Clean, VSCode-like rows: no size/type/date columns
      diagnostics = {
        symbols = { error = ' ', warn = ' ', hint = ' ', info = ' ' },
      },
      git_status = {
        symbols = {
          renamed = '󰁕',
          unstaged = '󰄱',
          staged = ' ',
          untracked = ' ',
          deleted = '',
          ignored = '',
        },
      },
    },
    filesystem = {
      -- Directory handling is done by prat.configs.autocmds (restore session +
      -- open tree). Hijacking here too caused a race that stole the window.
      hijack_netrw_behavior = 'disabled',
      follow_current_file = { enabled = true }, -- sidebar follows the file you're editing
      use_libuv_file_watcher = true,            -- auto-refresh when files change on disk
      refresh = {
        enable = true,
        updatetime = 200,                       -- pick up new files almost instantly
      },
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = true,
      },
      window = {
        width = 30,
        mappings = {
          ['\\'] = 'close_window',
          -- VSCode-style navigation
          ['<cr>'] = 'open',
          ['l'] = 'open',        -- expand folder / open file
          ['h'] = 'close_node',  -- collapse folder / go up
          ['<bs>'] = 'navigate_up',
          ['<C-.>'] = nil,       -- don't clash with LSP quick fix
        },
      },
    },
  },
}
