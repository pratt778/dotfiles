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

vim.keymap.set('n', '<C-x>', '"+dd', { desc = 'Cut line' })
vim.keymap.set('v', '<C-x>', '"+d', { desc = 'Cut selection' })
vim.keymap.set('i', '<C-x>', '<Esc>"+ddi', { desc = 'Cut line' })

local function open_file_picker()
  require('telescope.builtin').find_files()
end

local function open_recent_file_picker()
  require('telescope.builtin').oldfiles()
end

local function new_file_prompt()
  -- Default to the directory of the file you're currently editing (VSCode-style).
  -- Falls back to <project>/lib in Flutter projects, else the project root.
  local default_dir
  local current = vim.api.nvim_buf_get_name(0)
  if current ~= '' and vim.fn.filereadable(current) == 1 then
    default_dir = vim.fs.dirname(current)
  else
    default_dir = vim.fn.getcwd()
    if vim.fn.filereadable(default_dir .. '/pubspec.yaml') == 1 then
      default_dir = default_dir .. '/lib'
    end
  end

  while true do
    local input_path = vim.fn.input('New file: ', default_dir .. '/', 'file')
    if input_path == '' then
      return
    end

    local path = vim.fn.expand(input_path)
    if path == '' then
      return
    end

    -- If the user typed something that resolves to a folder, don't silently
    -- create junk — warn and let them fix the path.
    if vim.fn.isdirectory(path) == 1 then
      vim.notify(
        'That path is a folder. Add a filename at the end, e.g. ' .. vim.fs.basename(path) .. '/my_file.dart',
        vim.log.levels.WARN
      )
      default_dir = path
      goto continue
    end

    -- Create parent folders, then create the actual file on disk immediately
    -- (so it shows up in Neo-tree / find_files even before you save).
    local parent = vim.fs.dirname(path)
    if parent and parent ~= '' then
      vim.fn.mkdir(parent, 'p')
    end
    vim.fn.writefile({}, path)
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.notify('Created ' .. path, vim.log.levels.INFO)
    do
      return
    end
    ::continue::
  end
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

-- ── Project-wide search & replace (VSCode Ctrl+Shift+H) ─────────────────
-- Greps the whole project, lists matches in a quickfix window, then
-- replaces across every file and offers to save them all.
local function project_grep_replace()
  local search = vim.fn.input('Search in project for: ', vim.fn.expand '<cword>')
  if search == '' then
    return
  end

  -- 1. Find every match (ripgrep, same engine as <leader>sg)
  local results = vim.fn.systemlist { 'rg', '--vimgrep', '--smart-case', '--', search }
  if vim.v.shell_error ~= 0 or #results == 0 then
    vim.notify('No matches for "' .. search .. '" in the project', vim.log.levels.WARN)
    return
  end
  vim.fn.setqflist({}, ' ', { title = 'Project matches: ' .. search, lines = results, efm = '%f:%l:%c:%m' })
  vim.cmd 'copen'
  vim.notify(#results .. ' matches found in the quickfix list', vim.log.levels.INFO)

  -- 2. Ask what to replace them with
  local replacement = vim.fn.input('Replace "' .. search .. '" with: ')
  if replacement == '' then
    return
  end

  local pattern = vim.fn.escape(vim.pesc(search), '/')
  local escaped = vim.fn.escape(replacement, '/\\&')

  -- 3. Replace across every file in the quickfix list
  vim.cmd('silent! cfdo %s/' .. pattern .. '/' .. escaped .. '/g')

  -- 4. Offer to save everything
  local dirty = vim.tbl_filter(function(b)
    return vim.bo[b].modified and vim.bo[b].buftype == ''
  end, vim.api.nvim_list_bufs())
  if #dirty > 0 then
    local save = vim.fn.confirm('Save ' .. #dirty .. ' modified file(s)?', '&Yes\n&No', 1)
    if save == 1 then
      vim.cmd 'silent! wall'
    end
  end
  vim.notify('Replaced "' .. search .. '" → "' .. replacement .. '" in ' .. #results .. ' place(s)', vim.log.levels.INFO)
end

vim.keymap.set('n', '<leader>pr', project_grep_replace, { desc = 'Project-wide Replace' })
vim.keymap.set('v', '<leader>pr', function()
  vim.schedule(project_grep_replace)
end, { desc = 'Project-wide Replace' })

-- ── end project replace ──────────────────────────────────────────────────

-- ctrl backspace deletes the whole word (VSCode-style)
vim.keymap.set('i', '<C-BS>', '<C-w>', { desc = 'Delete word before cursor' })

-- Ctrl+Tab / Ctrl+Shift+Tab: cycle between open files (VSCode-style)
vim.keymap.set('n', '<C-Tab>', '<cmd>bnext<CR>', { desc = 'Next file (VSCode Ctrl+Tab)' })
vim.keymap.set('n', '<C-S-Tab>', '<cmd>bprevious<CR>', { desc = 'Previous file (VSCode Ctrl+Shift+Tab)' })
vim.keymap.set('i', '<C-Tab>', '<Esc><cmd>bnext<CR>a', { desc = 'Next file (VSCode Ctrl+Tab)' })
vim.keymap.set('i', '<C-S-Tab>', '<Esc><cmd>bprevious<CR>a', { desc = 'Previous file (VSCode Ctrl+Shift+Tab)' })

-- ── Terminal toggle (VSCode-style Ctrl+backtick, plus <leader>tt) ────────
-- Same key opens AND closes the terminal, from Normal, Insert or Terminal mode.
local function toggle_terminal()
  require('snacks').terminal.toggle(nil, { title = 'Terminal' })
end
vim.keymap.set({ 'n', 't' }, '<C-`>', toggle_terminal, { desc = 'Toggle terminal' })
vim.keymap.set({ 'n', 't' }, '<leader>tt', toggle_terminal, { desc = 'Toggle terminal' })
vim.keymap.set('i', '<C-`>', function()
  vim.cmd 'stopinsert'
  vim.schedule(toggle_terminal)
end, { desc = 'Toggle terminal' })

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

-- Tab / buffer switching (VSCode-style Ctrl+PageUp/Down and Shift+h/l)
vim.keymap.set('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer/tab' })
vim.keymap.set('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Previous buffer/tab' })
vim.keymap.set('n', '<C-PageDown>', '<cmd>bnext<CR>', { desc = 'Next tab (VSCode)' })
vim.keymap.set('n', '<C-PageUp>', '<cmd>bprevious<CR>', { desc = 'Previous tab (VSCode)' })

-- For half page scroll and center cursor_pos
--
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'half scroll and center cursor' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'half scroll and center cursor' })
