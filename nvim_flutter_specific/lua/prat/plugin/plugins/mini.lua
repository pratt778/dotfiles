return { -- Collection of various small independent plugins/modules
  {
    'echasnovski/mini.ai',
    opts = {},
  },
  {
    'echasnovski/mini.files',
    keys = {
      -- Keybindings
      {
        '<leader>em',
        function()
          require('mini.files').open(vim.api.nvim_buf_get_name(0), true)
        end,
        desc = 'Open mini.files (Directory of Current File)',
      },
      {
        '<leader>eM',
        function()
          require('mini.files').open(vim.uv.cwd(), true)
        end,
        desc = 'Open mini.files (cwd)',
      },
    },
    config = function()
      --for mini filesystem
      require('mini.files').setup {
        use_as_default_explorer = false,
      }
      -- Toggle Hidden Files
      local show_dotfiles = true
      local filter_show = function(_)
        return true
      end
      local filter_hide = function(fs_entry)
        return not vim.startswith(fs_entry.name, '.')
      end

      local toggle_dotfiles = function()
        show_dotfiles = not show_dotfiles
        local new_filter = show_dotfiles and filter_show or filter_hide
        require('mini.files').refresh { content = { filter = new_filter } }
      end

      -- Split Navigation
      local function map_split(buf_id, lhs, direction, close_on_file)
        local rhs = function()
          local new_target_window
          local cur_target_window = require('mini.files').get_explorer_state().target_window
          if cur_target_window ~= nil then
            vim.api.nvim_win_call(cur_target_window, function()
              vim.cmd('belowright ' .. direction .. ' split')
              new_target_window = vim.api.nvim_get_current_win()
            end)

            require('mini.files').set_target_window(new_target_window)
            require('mini.files').go_in { close_on_file = close_on_file }
          end
        end

        local desc = 'Open in ' .. direction .. ' split' .. (close_on_file and ' and close' or '')
        vim.keymap.set('n', lhs, rhs, { buffer = buf_id, desc = desc })
      end

      -- Change CWD to Current File's Directory
      local function files_set_cwd()
        local cur_entry_path = require('mini.files').get_fs_entry().path
        local cur_directory = vim.fs.dirname(cur_entry_path)
        if cur_directory ~= nil then
          vim.fn.chdir(cur_directory)
        end
      end

      local function focused_directory()
        local state = require('mini.files').get_explorer_state()
        if state == nil then
          return vim.uv.cwd()
        end

        local path = state.branch[state.depth_focus]
        if path == nil then
          return vim.uv.cwd()
        end

        local entry = require('mini.files').get_fs_entry()
        if entry ~= nil and entry.fs_type == 'file' then
          return vim.fs.dirname(entry.path) or path
        end

        return path
      end

      local function create_entry()
        local base_dir = focused_directory()
        local name = vim.fn.input('Create (use / for folder): ', '', 'file')
        if name == '' then
          return
        end

        local path = vim.fn.expand(base_dir .. '/' .. name)
        local parent = vim.fs.dirname(path)
        if parent and parent ~= '' then
          vim.fn.mkdir(parent, 'p')
        end

        if name:sub(-1) == '/' then
          vim.fn.mkdir(path, 'p')
        else
          vim.fn.writefile({}, path)
        end

        require('mini.files').open(base_dir, true)
      end

      local function delete_entry()
        local entry = require('mini.files').get_fs_entry()
        if entry == nil then
          vim.notify('Cursor is not on a file or folder', vim.log.levels.WARN)
          return
        end

        local confirm = vim.fn.confirm('Delete ' .. entry.path .. '?', '&Yes\n&No', 2)
        if confirm ~= 1 then
          return
        end

        vim.fn.delete(entry.path, 'rf')
        require('mini.files').open(focused_directory(), true)
      end

      -- Auto Commands for MiniFiles
      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniFilesBufferCreate',
        callback = function(args)
          local buf_id = args.data.buf_id

          vim.keymap.set('n', 'g.', toggle_dotfiles, { buffer = buf_id, desc = 'Toggle hidden files' })
          vim.keymap.set('n', 'gc', files_set_cwd, { buffer = buf_id, desc = 'Set cwd' })
          vim.keymap.set('n', 'a', create_entry, { buffer = buf_id, desc = 'Create file or folder' })
          vim.keymap.set('n', 'D', delete_entry, { buffer = buf_id, desc = 'Delete file or folder' })

          map_split(buf_id, '<C-w>s', 'horizontal', false)
          map_split(buf_id, '<C-w>v', 'vertical', false)
          map_split(buf_id, '<C-w>S', 'horizontal', true)
          map_split(buf_id, '<C-w>V', 'vertical', true)
        end,
      })

      -- File Rename Hook (You may need to replace `Snacks.rename.on_rename_file` with your own function)
      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniFilesActionRename',
        callback = function(event)
          -- Replace with your custom function if needed
          print('File renamed from ' .. event.data.from .. ' to ' .. event.data.to)
        end,
      })
    end,
  },
  {
    'echasnovski/mini.surround',
    opts = {},
  },
  {
    'echasnovski/mini.statusline',
    config = function()
      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },
}
