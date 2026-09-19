-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Disable netrw: directories are handled below (restore session + tree).
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- `nvim .` = pick up where you left off: restore the last session (your
-- previous file opens) and show the project tree as a sidebar.
-- NOTE: with netrw disabled, BufEnter does NOT fire for directory buffers,
-- so this hooks VimEnter and takes the directory from the current buffer.
vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'nvim <dir>: restore this project session and show tree',
  group = vim.api.nvim_create_augroup('prat-dir-restore-session', { clear = true }),
  callback = function()
    -- argv() can be empty inside VimEnter; the opened directory buffer is
    -- the reliable source (it is the current buffer at this point).
    local dir = vim.api.nvim_buf_get_name(0)
    if dir == '' or vim.fn.isdirectory(dir) ~= 1 then
      return
    end
    vim.cmd.cd(vim.fn.fnameescape(dir))
    vim.defer_fn(function()
      -- Restore the session saved for THIS project (opens your last file(s))
      local ok = pcall(function()
        require('persistence').load()
      end)

      -- Find a real file buffer from the session (not neo-tree, not a dir)
      local file_buf
      for _, info in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
        local name = vim.api.nvim_buf_get_name(info.bufnr)
        if
          name ~= ''
          and vim.bo[info.bufnr].buftype == ''
          and not name:find('neo%-tree')
          and vim.fn.isdirectory(name) ~= 1
        then
          file_buf = info.bufnr
          break
        end
      end

      if file_buf then
        -- Your file takes the main window; tree becomes a left sidebar
        vim.api.nvim_win_set_buf(0, file_buf)
        -- Close any tree windows the session restored — we open exactly ONE
        -- (collect first, then close: never mutate while iterating windows)
        local restored_trees = {}
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):find('neo%-tree') then
            table.insert(restored_trees, w)
          end
        end
        for _, w in ipairs(restored_trees) do
          if vim.api.nvim_win_is_valid(w) then
            pcall(vim.api.nvim_win_close, w, true)
          end
        end
        local show_ok, show_err = pcall(function()
          require('neo-tree.command').execute {
            action = 'show',
            source = 'filesystem',
            position = 'left',
            dir = vim.fn.getcwd(),
          }
        end)
        -- Keep focus on your file if the tree or an empty buffer grabbed it
        vim.defer_fn(function()
          local cur = vim.api.nvim_buf_get_name(0)
          if cur:find('neo%-tree') or cur == '' then
            for _, w in ipairs(vim.api.nvim_list_wins()) do
              local b = vim.api.nvim_win_get_buf(w)
              local n = vim.api.nvim_buf_get_name(b)
              if n ~= '' and vim.bo[b].buftype == '' and not n:find('neo%-tree') then
                vim.api.nvim_set_current_win(w)
                break
              end
            end
          end
        end, 250)
      else
        -- No previous session: take over the window with the tree, like before
        pcall(function()
          require('neo-tree.command').execute {
            action = 'show',
            source = 'filesystem',
            position = 'current',
            dir = vim.fn.getcwd(),
          }
        end)
        if not ok then
          vim.notify('No previous session — browse with the tree (l / Enter)', vim.log.levels.INFO)
        else
          vim.notify('No file to restore — browse with the tree (l / Enter)', vim.log.levels.INFO)
        end
      end

      -- Wipe leftover directory buffers and close empty leftover windows
      vim.defer_fn(function()
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          local n = vim.api.nvim_buf_get_name(b)
          if n ~= '' and vim.fn.isdirectory(n) == 1 then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end

        -- Close stray [No Name] split windows (collect first, then close;
        -- never touch neo-tree windows)
        local stray = {}
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if w ~= vim.api.nvim_get_current_win() then
            local b = vim.api.nvim_win_get_buf(w)
            local name = vim.api.nvim_buf_get_name(b)
            if
              name == ''
              and vim.bo[b].buftype == ''
              and vim.bo[b].filetype ~= 'neo-tree'
              and not name:find('neo%-tree')
            then
              table.insert(stray, w)
            end
          end
        end
        for _, w in ipairs(stray) do
          if vim.api.nvim_win_is_valid(w) and #vim.api.nvim_list_wins() > 1 then
            pcall(vim.api.nvim_win_close, w, true)
          end
        end
      end, 200)
    end, 10)
  end,
})

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
