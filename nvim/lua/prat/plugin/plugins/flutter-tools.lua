return {
  'akinsho/flutter-tools.nvim',
  ft = 'dart',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'stevearc/dressing.nvim',
    'mfussenegger/nvim-dap',
  },
  config = function()
    require('flutter-tools').setup {
      lsp = {
        color = {
          enable = true,
          foreground = true,
        },
      },
      debugger = {
        enabled = true,
        run_via_dap = true,
        register_configurations = function(paths)
          require('dap.ext.vscode').load_launchjs()
        end,
      },
      dev_log = {
        enabled = true,
        filter = nil, -- optional callback to filter the log
        notify_errors = false, -- if there is an error whilst running then notify the user
        open_cmd = 'botright split', -- command to use to open the log buffer
        focus_on_open = true, -- focus on the newly opened log window
      },
    }
    -- Helper for terminal commands
    local function run_flutter_cmd(cmd, title)
      return function()
        require('snacks').terminal.toggle(cmd, { title = title })
      end
    end

    -- ── Flutter run-status indicator ──────────────────────────────────────
    -- Tracks building / running / stopped by watching the flutter dev log
    -- and the commands you trigger. Badge shows in the statusline;
    -- <leader>fs prints a detailed status any time.
    local flutter_state = { status = 'stopped', since = os.time(), last_event = '—', log_buf = nil, scanned = 0 }
    _G._flutter_state = flutter_state -- exposed for debugging / <leader>fs

    local function set_flutter_state(status, event)
      if flutter_state.status == status then
        return
      end
      flutter_state.status = status
      flutter_state.since = os.time()
      if event then
        flutter_state.last_event = event
      end
      local msg = {
        building = '⏳ Flutter: building…',
        running = '🟢 Flutter: app running',
        stopped = '🛑 Flutter: app stopped',
      }
      if msg[status] then
        vim.notify(msg[status], vim.log.levels.INFO, { title = 'Flutter (' .. (event or flutter_state.last_event) .. ')' })
      end
      vim.cmd 'redrawstatus'
    end

    _G.FlutterAppStatus = function()
      if flutter_state.status == 'building' then
        return '⏳ building…'
      elseif flutter_state.status == 'running' then
        return '🟢 running'
      end
      return ''
    end

    local function flutter_cmd_with_status(cmd, status, event)
      return function()
        set_flutter_state(status, event)
        vim.cmd(cmd)
      end
    end

    local MARKERS = {
      building = { 'Launching lib/main.dart', 'Running Gradle task', 'Performing hot reload', 'Performing hot restart' },
      running = { 'A Dart VM Service on', 'Reloaded ', 'Restarted application' },
      stopped = { 'Application finished', 'Application terminated', 'Lost connection to device', 'Quit (terminate the application' },
    }

    local function scan_fresh_log_lines(lines)
      local found
      for _, line in ipairs(lines) do
        for status, markers in pairs(MARKERS) do
          for _, marker in ipairs(markers) do
            if line:find(marker, 1, true) then
              found = { status, line:sub(1, 70) }
            end
          end
        end
      end
      return found
    end

    local uv = vim.uv or vim.loop
    local status_timer = uv.new_timer()
    status_timer:start(1500, 1500, vim.schedule_wrap(function()
      local log_buf
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(b)
        if name:find('flutter-tools', 1, true) and name:find('log', 1, true) then
          log_buf = b
          break
        end
      end
      if not log_buf or not vim.api.nvim_buf_is_loaded(log_buf) then
        return
      end
      local total = vim.api.nvim_buf_line_count(log_buf)
      if flutter_state.log_buf ~= log_buf then
        -- First time seeing this log: only look at the tail, not old history
        flutter_state.log_buf = log_buf
        flutter_state.scanned = math.max(0, total - 40)
      end
      if total <= flutter_state.scanned then
        return
      end
      local fresh = vim.api.nvim_buf_get_lines(log_buf, flutter_state.scanned, total, false)
      flutter_state.scanned = total
      local found = scan_fresh_log_lines(fresh)
      if found then
        set_flutter_state(found[1], found[2])
      end
    end))

    -- Debug runs (F5 / launch.json) through DAP also update the status
    local ok_dap, dap = pcall(require, 'dap')
    if ok_dap then
      dap.listeners.after.event_initialized['flutter_status'] = function()
        set_flutter_state('building', 'debug session started')
      end
      dap.listeners.before.event_terminated['flutter_status'] = function()
        set_flutter_state('stopped', 'debug session ended')
      end
    end
    -- ── end status indicator ──────────────────────────────────────────────

    -- Unified Flutter Telescope Picker
    local custom_flutter_picker = function()
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local conf = require('telescope.config').values
      local actions = require 'telescope.actions'
      local action_state = require 'telescope.actions.state'
      local themes = require 'telescope.themes'

      local commands = {
        { '▶  Run App', flutter_cmd_with_status('FlutterRun', 'building', 'flutter run') },
        { '⚙  Run with Config (launch.json)', function() require('dap').continue() end },
        { '🔄 Hot Restart', flutter_cmd_with_status('FlutterRestart', 'building', 'hot restart') },
        { '⚡ Hot Reload', flutter_cmd_with_status('FlutterReload', 'building', 'hot reload') },
        { '📥 Pub Get', 'FlutterPubGet' },
        { '⬆  Pub Upgrade', 'FlutterPubUpgrade' },
        { '🧹 Clean Project', run_flutter_cmd('flutter clean', 'Flutter Clean') },
        { '✨ Clean & Pub Get', run_flutter_cmd('flutter clean && flutter pub get', 'Clean & Pub Get') },
        { '🏗  Build Runner', run_flutter_cmd('dart run build_runner build --delete-conflicting-outputs', 'Build Runner') },
        { '🛠  Dart Fix Apply', run_flutter_cmd('dart fix --apply', 'Dart Fix') },
        { '🔍 Analyze Code', run_flutter_cmd('flutter analyze', 'Flutter Analyze') },
        { '📱 Select Device', 'FlutterDevices' },
        { '🎮 Emulators', 'FlutterEmulators' },
        { '📋 Toggle Logs', 'FlutterLogToggle' },
        { '🌐 DevTools', 'FlutterDevTools' },
        { '🛑 Quit App', flutter_cmd_with_status('FlutterQuit', 'stopped', 'flutter quit') },
      }

      pickers
        .new(themes.get_dropdown {}, {
          prompt_title = 'Flutter Tools',
          finder = finders.new_table {
            results = commands,
            entry_maker = function(entry)
              return {
                value = entry,
                display = entry[1],
                ordinal = entry[1],
              }
            end,
          },
          sorter = conf.generic_sorter {},
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              local cmd = selection.value[2]
              if type(cmd) == 'string' then
                vim.cmd(cmd)
              else
                cmd()
              end
            end)
            return true
          end,
        })
        :find()
    end

    vim.keymap.set('n', '<leader>fl', custom_flutter_picker, { desc = 'flutter tools' })
    vim.keymap.set('n', '<leader>fd', '<cmd>FlutterLogToggle<CR>', { desc = 'flutter logs' })

    -- Hot Restart: <Alt+e> (recompiles and restarts the app)
    vim.keymap.set('n', '<A-e>', '<cmd>FlutterRestart<CR>', { desc = 'Flutter: Hot Restart' })

    -- Save + Hot Reload: <Alt+o> (writes the file, then reloads the running app)
    local function save_and_hot_reload()
      if vim.bo.modified and vim.api.nvim_buf_get_name(0) ~= '' then
        vim.cmd 'silent write'
      end
      if vim.bo.filetype == 'dart' then
        vim.cmd 'FlutterReload'
      else
        vim.notify('Hot reload only works in a .dart file with the app running', vim.log.levels.WARN)
      end
    end
    vim.keymap.set({ 'n', 'i' }, '<A-o>', function()
      set_flutter_state('building', 'hot reload (Alt+o)')
      save_and_hot_reload()
    end, { desc = 'Flutter: Save + Hot Reload' })

    vim.keymap.set('n', '<A-e>', function()
      set_flutter_state('building', 'hot restart (Alt+e)')
      vim.cmd 'FlutterRestart'
    end, { desc = 'Flutter: Hot Restart' })

    -- Run with debugger (Alt+p): starts/continues the debug session
    vim.keymap.set({ 'n', 'i' }, '<A-p>', function()
      set_flutter_state('building', 'debug run (Alt+p)')
      require('dap').continue()
    end, { desc = 'Flutter: Run with Debugger' })

    -- Detailed status: is the app building, running, or stopped?
    vim.keymap.set('n', '<leader>fs', function()
      local s = flutter_state.status
      local secs = os.time() - flutter_state.since
      local mins = math.floor(secs / 60)
      local dur = mins > 0 and string.format('%dm%ds', mins, secs % 60) or (secs .. 's')
      local icon = ({ building = '⏳', running = '🟢', stopped = '🛑' })[s] or '❔'
      vim.notify(
        ('Flutter app: %s %s\nIn this state for: %s\nLast event: %s'):format(icon, s:upper(), dur, flutter_state.last_event),
        vim.log.levels.INFO,
        { title = 'Flutter Status' }
      )
    end, { desc = 'Flutter: show app status' })
  end,
}
