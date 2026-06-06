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

    -- Unified Flutter Telescope Picker
    local custom_flutter_picker = function()
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local conf = require('telescope.config').values
      local actions = require 'telescope.actions'
      local action_state = require 'telescope.actions.state'
      local themes = require 'telescope.themes'

      local commands = {
        { '▶  Run App', 'FlutterRun' },
        { '⚙  Run with Config (launch.json)', function() require('dap').continue() end },
        { '🔄 Hot Restart', 'FlutterRestart' },
        { '⚡ Hot Reload', 'FlutterReload' },
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
        { '🛑 Quit App', 'FlutterQuit' },
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
  end,
}
