-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
--

vim.keymap.set('i', ';;', '<Esc>', { desc = 'Exit insert mode' })
-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Familiar editor-style shortcuts.
vim.keymap.set('n', '<C-s>', '<cmd>write<CR>', { desc = 'Save file' })
vim.keymap.set('i', '<C-s>', '<Esc><cmd>write<CR>a', { desc = 'Save file' })
vim.keymap.set('v', '<C-s>', '<Esc><cmd>write<CR>', { desc = 'Save file' })

vim.keymap.set('n', '<C-z>', 'u', { desc = 'Undo' })
vim.keymap.set('i', '<C-z>', '<Esc>ui', { desc = 'Undo' })
vim.keymap.set('v', '<C-z>', '<Esc>u', { desc = 'Undo' })

vim.keymap.set('n', '<C-r>', '<C-r>', { desc = 'Redo' })
vim.keymap.set('i', '<C-r>', '<Esc><C-r>i', { desc = 'Redo' })
vim.keymap.set('v', '<C-r>', '<Esc><C-r>', { desc = 'Redo' })
vim.keymap.set('n', '<C-S-z>', '<C-r>', { desc = 'Redo' })
vim.keymap.set('i', '<C-S-z>', '<Esc><C-r>i', { desc = 'Redo' })
vim.keymap.set('v', '<C-S-z>', '<Esc><C-r>', { desc = 'Redo' })

local function select_all()
  vim.cmd 'normal! gg0'
  vim.cmd 'normal! VG'
end

vim.keymap.set('n', '<C-a>', select_all, { desc = 'Select all' })
vim.keymap.set('i', '<C-a>', function()
  vim.cmd 'stopinsert'
  vim.schedule(select_all)
end, { desc = 'Select all' })
vim.keymap.set('v', '<C-a>', function()
  vim.cmd 'normal! \27'
  select_all()
end, { desc = 'Select all' })

vim.keymap.set('n', '<C-c>', '"+yy', { desc = 'Copy line' })
vim.keymap.set('v', '<C-c>', '"+y', { desc = 'Copy selection' })

vim.keymap.set('n', '<C-v>', '"+p', { desc = 'Paste' })
vim.keymap.set('i', '<C-v>', '<C-r>+', { desc = 'Paste' })
vim.keymap.set('v', '<C-v>', '"_d"+P', { desc = 'Paste over selection' })

local function open_file_picker()
  require('telescope.builtin').find_files()
end

local function open_recent_file_picker()
  require('telescope.builtin').oldfiles()
end

local function new_file_prompt()
  local path = vim.fn.input('New file: ', '', 'file')
  if path == '' then
    return
  end

  local expanded_path = vim.fn.expand(path)
  local parent = vim.fs.dirname(expanded_path)
  if parent and parent ~= '' then
    vim.fn.mkdir(parent, 'p')
  end

  vim.cmd.edit(vim.fn.fnameescape(expanded_path))
end

local function open_file_explorer()
  require('mini.files').open(vim.uv.cwd(), true)
end

vim.keymap.set('n', '<C-o>', open_file_picker, { desc = 'Open file' })
vim.keymap.set('i', '<C-o>', function()
  vim.cmd 'stopinsert'
  vim.schedule(open_file_picker)
end, { desc = 'Open file' })
vim.keymap.set('n', '<C-S-o>', open_recent_file_picker, { desc = 'Open recent file' })
vim.keymap.set('i', '<C-S-o>', function()
  vim.cmd 'stopinsert'
  vim.schedule(open_recent_file_picker)
end, { desc = 'Open recent file' })

vim.keymap.set('n', '<C-n>', new_file_prompt, { desc = 'New file' })
vim.keymap.set('i', '<C-n>', function()
  vim.cmd 'stopinsert'
  vim.schedule(new_file_prompt)
end, { desc = 'New file' })

vim.keymap.set('n', '<C-e>', open_file_explorer, { desc = 'File explorer' })
vim.keymap.set('i', '<C-e>', function()
  vim.cmd 'stopinsert'
  vim.schedule(open_file_explorer)
end, { desc = 'File explorer' })

local function selected_text()
  local saved_text = vim.fn.getreg('z')
  local saved_type = vim.fn.getregtype('z')

  vim.cmd('normal! "zy')
  local text = vim.fn.getreg('z')

  vim.fn.setreg('z', saved_text, saved_type)
  return text:gsub('\n', '\\n')
end

local function search_prompt(default)
  local query = vim.fn.input('Find: ', default or vim.fn.expand '<cword>')
  if query == '' then
    return
  end

  vim.fn.setreg('/', vim.pesc(query))
  vim.opt.hlsearch = true
  vim.cmd 'normal! n'
end

local function replace_prompt(replace_all, default)
  local query = vim.fn.input('Find: ', default or vim.fn.expand '<cword>')
  if query == '' then
    return
  end

  local replacement = vim.fn.input('Replace with: ')
  local pattern = vim.fn.escape(vim.pesc(query), '/')
  local escaped_replacement = vim.fn.escape(replacement, '/\\&')
  local flags = replace_all and 'g' or 'gc'

  vim.cmd('%s/' .. pattern .. '/' .. escaped_replacement .. '/' .. flags)
end

vim.keymap.set('n', '<C-f>', function()
  search_prompt()
end, { desc = 'Find' })
vim.keymap.set('i', '<C-f>', function()
  vim.cmd 'stopinsert'
  vim.schedule(search_prompt)
end, { desc = 'Find' })
vim.keymap.set('v', '<C-f>', function()
  search_prompt(selected_text())
end, { desc = 'Find selection' })

vim.keymap.set('n', '<C-h>', function()
  replace_prompt(false)
end, { desc = 'Replace' })
vim.keymap.set('i', '<C-h>', function()
  vim.cmd 'stopinsert'
  vim.schedule(function()
    replace_prompt(false)
  end)
end, { desc = 'Replace' })
vim.keymap.set('v', '<C-h>', function()
  replace_prompt(false, selected_text())
end, { desc = 'Replace selection' })

vim.keymap.set('n', '<C-S-h>', function()
  replace_prompt(true)
end, { desc = 'Replace all' })
vim.keymap.set('i', '<C-S-h>', function()
  vim.cmd 'stopinsert'
  vim.schedule(function()
    replace_prompt(true)
  end)
end, { desc = 'Replace all' })
vim.keymap.set('v', '<C-S-h>', function()
  replace_prompt(true, selected_text())
end, { desc = 'Replace all selection' })
vim.keymap.set({ 'n', 'v' }, '<leader>ra', function()
  replace_prompt(true)
end, { desc = 'Replace all' })

-- ctrl backspace for deletion
-- vim.keymap.set('i', '<C-BS>', '<C-w>', { desc = 'ctrl backspace for delete word' })

-- Diagnostic keymaps
-- TODO: remove this for trouble.nvim vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('n', '<leader>sm', '<C-w>|', { desc = 'Maximize width of split' })
vim.keymap.set('n', '<leader>s=', '<C-w>=', { desc = 'Equalizeo split' })

-- For half page scroll and center cursor_pos
--
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'half scroll and center cursor' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'half scroll and center cursor' })
