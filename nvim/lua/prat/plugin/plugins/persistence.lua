return {
  'folke/persistence.nvim',
  lazy = false,
  opts = {
    branch = false, -- Tie session to project folder so it always restores
  },
  keys = {
    { '<leader>qs', function() require('persistence').load() end, desc = 'Restore Session' },
    { '<leader>ql', function() require('persistence').load { last = true } end, desc = 'Restore Last Session' },
    { '<leader>qd', function() require('persistence').stop() end, desc = "Don't Save Current Session" },
  },
}
