-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Guard for Neovim 0.12+ strict validation in nvim_echo where plugins
-- (such as flutter-tools) pass an unsupported `source` key in opts.
local orig_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  if opts and opts.source ~= nil then
    opts = vim.deepcopy(opts)
    opts.source = nil
  end
  return orig_echo(chunks, history, opts)
end

-- Disable netrw: directories are handled below (restore session + tree).
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- `nvim .` or `nvim` (no file args) = pick up where you left off: restore the
-- last session (your previous file opens) and show the project tree as a sidebar.
vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'nvim or nvim <dir>: restore this project session and show tree',
  group = vim.api.nvim_create_augroup('prat-dir-restore-session', { clear = true }),
  callback = function()
    local is_dir = false
    local dir = vim.api.nvim_buf_get_name(0)
    if dir ~= '' and vim.fn.isdirectory(dir) == 1 then
      is_dir = true
      vim.cmd.cd(vim.fn.fnameescape(dir))
    end

    -- If a specific file was passed (e.g. `nvim main.dart`), do not hijack with session
    if not is_dir and vim.fn.argc() > 0 then
      return
    end

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
        -- Close any tree windows and wipe any tree buffers the session restored — we open exactly ONE clean instance
        local restored_trees = {}
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local b = vim.api.nvim_win_get_buf(w)
          if vim.api.nvim_buf_get_name(b):find('neo%-tree') or vim.bo[b].filetype == 'neo-tree' then
            table.insert(restored_trees, w)
          end
        end
        for _, w in ipairs(restored_trees) do
          if vim.api.nvim_win_is_valid(w) then
            pcall(vim.api.nvim_win_close, w, true)
          end
        end
        -- Wipe any neo-tree buffers lingering in memory so name collisions never happen
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(b) then
            local name = vim.api.nvim_buf_get_name(b)
            if name:find('neo%-tree') or vim.bo[b].filetype == 'neo-tree' then
              pcall(vim.api.nvim_buf_delete, b, { force = true })
            end
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

-- Close Neo-tree cleanly on exit before saving sessions so it is never serialized into session files
vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'Close Neo-tree before saving session on exit',
  group = vim.api.nvim_create_augroup('prat-neotree-session-clean', { clear = true }),
  callback = function()
    pcall(function()
      require('neo-tree.command').execute { action = 'close' }
    end)
  end,
})

-- Safely cleanup dead or crashed DAP debug sessions so ExitPre never throws "cannot resume dead coroutine"
vim.api.nvim_create_autocmd('ExitPre', {
  desc = 'Safely cleanup dead DAP sessions on exit',
  group = vim.api.nvim_create_augroup('prat-dap-clean-exit', { clear = true }),
  callback = function()
    local ok, dap = pcall(require, 'dap')
    if ok and dap and dap.sessions then
      for _, s in pairs(dap.sessions()) do
        if s and (s.closed or not s.client or (s.coro and coroutine.status(s.coro) == 'dead')) then
          pcall(function()
            s:close()
          end)
        end
      end
    end
  end,
})

-- Continuous crash / power-cut proof session saving:
-- Automatically updates the session file on disk when saving files, when app loses focus,
-- or periodically every 2 minutes so unexpected power loss never loses your session.
local function trigger_session_save()
  local ok, persistence = pcall(require, 'persistence')
  if not ok or not persistence then
    return
  end
  local real_files = vim.tbl_filter(function(b)
    if not vim.api.nvim_buf_is_valid(b) or not vim.bo[b].buflisted or vim.bo[b].buftype ~= '' then
      return false
    end
    local name = vim.api.nvim_buf_get_name(b)
    return name ~= '' and vim.fn.filereadable(name) == 1 and not name:find('neo%-tree')
  end, vim.api.nvim_list_bufs())

  if #real_files > 0 then
    pcall(persistence.save)
  end
end

vim.api.nvim_create_autocmd({ 'BufWritePost', 'FocusLost' }, {
  desc = 'Continuously auto-save session on file save or app blur',
  group = vim.api.nvim_create_augroup('prat-auto-save-session', { clear = true }),
  callback = function()
    trigger_session_save()
  end,
})

local session_timer = vim.uv.new_timer()
if session_timer then
  session_timer:start(120000, 120000, vim.schedule_wrap(trigger_session_save))
end
