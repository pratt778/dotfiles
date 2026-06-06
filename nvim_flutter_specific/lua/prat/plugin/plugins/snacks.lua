return {
  'folke/snacks.nvim',

  config = function()
    local function open_folder()
      vim.cmd.edit(vim.fn.fnameescape(vim.uv.cwd()))
    end

    local function select_folder()
      local folder = vim.fn.input('Folder: ', vim.uv.cwd(), 'dir')
      if folder == '' then
        return
      end

      local expanded = vim.fn.expand(folder)
      if vim.fn.isdirectory(expanded) == 0 then
        vim.notify('Not a directory: ' .. expanded, vim.log.levels.WARN)
        return
      end

      vim.fn.chdir(expanded)
      vim.cmd.edit(vim.fn.fnameescape(expanded))
    end

    require('snacks').setup {
      scroll = {},
      lazygit = {},
      notifier = {},
      toggle = {},
      indent = {},
      animate = {},
      words = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = ' ', key = 'o', desc = 'Open Folder', action = open_folder },
            { icon = ' ', key = 'd', desc = 'Select Folder', action = select_folder },
            { icon = ' ', key = 'n', desc = 'New File', action = '<C-n>' },
            { icon = ' ', key = 'f', desc = 'Find File', action = '<leader>sf' },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = '<leader>s.' },
            { icon = ' ', key = 'c', desc = 'Config', action = "<leader>sn" },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
          },
        },
      },
    }
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { desc = 'Snacks: ' .. desc })
    end

    map('<leader>lg', function()
      Snacks.lazygit()
    end, 'lazygit')
    map('<leader>gg', function()
      Snacks.terminal.toggle('gemini')
    end, 'Gemini New', { 'n', 't' })
    map('<leader>gr', function()
      Snacks.terminal.toggle('gemini -r')
    end, 'Gemini Resume List', { 'n', 't' })
    map('<leader>gl', function()
      Snacks.terminal.toggle('gemini -r latest')
    end, 'Gemini Resume Latest', { 'n', 't' })
    map('<leader>nh', function()
      Snacks.notifier.show_history()
    end, 'Notification History')
    map('<leader>bd', function()
      Snacks.bufdelete()
    end, 'Buffer Delete')
    map('<leader>nd', function()
      Snacks.notifier.hide()
    end, 'Buffer Delete')

    Snacks.toggle.animate():map '<leader>tA'
    Snacks.toggle.indent():map '<leader>ti'
    Snacks.toggle.inlay_hints():map '<leader>th'
    -- vim.keymap.set('n', '<', rhs, opts?)
  end,
}
