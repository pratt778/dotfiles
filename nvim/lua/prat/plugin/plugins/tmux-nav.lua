return {
  'christoomey/vim-tmux-navigator',
  init = function()
    -- Prevent vim-tmux-navigator from hijacking <C-h> (Ctrl+h is reserved for Find & Replace)
    vim.g.tmux_navigator_no_mappings = 1
  end,
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    'TmuxNavigatePrevious',
  },
  keys = {
    -- Do not bind <c-h> or <c-j> here (Ctrl+h = Replace, Ctrl+j = Terminal toggle)
    { '<c-k>', '<cmd><C-U>TmuxNavigateUp<cr>', desc = 'Navigate Up' },
    { '<c-l>', '<cmd><C-U>TmuxNavigateRight<cr>', desc = 'Navigate Right' },
    { '<c-\\>', '<cmd><C-U>TmuxNavigatePrevious<cr>', desc = 'Navigate Previous' },
  },
}
