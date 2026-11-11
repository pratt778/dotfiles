return {
  'akinsho/flutter-tools.nvim',
  lazy = false,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'stevearc/dressing.nvim',
    'mfussenegger/nvim-dap',
  },
  config = function()
    -- Guard for Neovim 0.12+ strict validation in nvim_echo where plugins
    -- pass an unsupported `source` key in opts.
    local orig_echo = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks, history, opts)
      if opts and opts.source ~= nil then
        opts = vim.deepcopy(opts)
        opts.source = nil
      end
      return orig_echo(chunks, history, opts)
    end

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local ok_cmp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
    if ok_cmp then
      capabilities = vim.tbl_deep_extend('force', capabilities, cmp_lsp.default_capabilities())
    end

    require('flutter-tools').setup {
      lsp = {
        color = {
          enabled = true,
          foreground = true,
        },
        capabilities = capabilities,
      },
      debugger = {
        enabled = true,
        -- Prevent debugger from halting on Flutter internal framework.dart exceptions
        -- Breakpoints set manually with <leader>b will still pause cleanly in your code!
        exception_breakpoints = {},
        register_configurations = function(paths)
          pcall(function()
            require('dap.ext.vscode').load_launchjs()
          end)
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

    -- ── Flutter Log Jump-to-File & Error Highlighting ──────────────────────
    local function open_flutter_log_file()
      local line = vim.api.nvim_get_current_line()
      local file_path, line_nr, col_nr

      -- 1. package:<app_name>/<path>.dart:<line>:<col>
      local pkg_path, l1, c1 = line:match('package:[%w_%-]+/([^:%s%)]+%.dart):(%d+):?(%d*)')
      if pkg_path then
        file_path = 'lib/' .. pkg_path
        line_nr = tonumber(l1)
        col_nr = tonumber(c1)
      end

      -- 2. lib/...dart:line:col or relative path
      if not file_path then
        local p2, l2, c2 = line:match('([%w_%-./\\]+%.dart):(%d+):?(%d*)')
        if p2 then
          file_path = p2
          line_nr = tonumber(l2)
          col_nr = tonumber(c2)
        end
      end

      -- 3. (file.dart:line)
      if not file_path then
        local p3, l3 = line:match('%(([%w_%-./\\]+%.dart):(%d+)%)')
        if p3 then
          file_path = p3
          line_nr = tonumber(l3)
        end
      end

      if not file_path then
        local ok = pcall(vim.cmd, 'normal! gF')
        if not ok then
          vim.notify('No file reference found on this line', vim.log.levels.WARN)
        end
        return
      end

      -- Resolve real file path on disk
      local full_path = file_path
      if vim.fn.filereadable(full_path) ~= 1 then
        full_path = vim.fn.getcwd() .. '/' .. file_path
      end
      if vim.fn.filereadable(full_path) ~= 1 then
        local basename = vim.fs.basename(file_path)
        local found = vim.fn.glob(vim.fn.getcwd() .. '/**/' .. basename, true, true)
        if #found > 0 then
          full_path = found[1]
        end
      end

      if vim.fn.filereadable(full_path) ~= 1 then
        vim.notify('Could not find file: ' .. file_path, vim.log.levels.WARN)
        return
      end

      -- Find a window that is not the log window to open the file in
      local log_win = vim.api.nvim_get_current_win()
      local target_win = nil
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if w ~= log_win then
          local b = vim.api.nvim_win_get_buf(w)
          local name = vim.api.nvim_buf_get_name(b)
          if not name:find('__FLUTTER_DEV_LOG__') and vim.bo[b].filetype ~= 'neo-tree' then
            target_win = w
            break
          end
        end
      end

      if target_win and vim.api.nvim_win_is_valid(target_win) then
        vim.api.nvim_set_current_win(target_win)
      else
        vim.cmd 'wincmd k'
      end

      vim.cmd.edit(vim.fn.fnameescape(full_path))
      if line_nr then
        pcall(vim.api.nvim_win_set_cursor, 0, { line_nr, math.max(0, (col_nr or 1) - 1) })
        vim.cmd 'normal! zz'
      end
      vim.notify('Jumped to ' .. vim.fs.basename(full_path) .. ':' .. (line_nr or 1), vim.log.levels.INFO)
    end

    local function setup_flutter_log_buffer(buf)
      if not buf or not vim.api.nvim_buf_is_valid(buf) or vim.b[buf]._flutter_log_setup then
        return
      end
      vim.b[buf]._flutter_log_setup = true

      -- Keymaps: Enter, gd, or double-click to jump to the file and line number
      vim.keymap.set('n', '<CR>', open_flutter_log_file, { buffer = buf, silent = true, desc = 'Jump to file and line' })
      vim.keymap.set('n', 'gd', open_flutter_log_file, { buffer = buf, silent = true, desc = 'Jump to file and line' })
      vim.keymap.set('n', '<2-LeftMouse>', open_flutter_log_file, { buffer = buf, silent = true, desc = 'Jump to file and line' })
      vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf, silent = true, desc = 'Close log window' })

      -- Red & colored syntax highlighting for Flutter errors
      vim.api.nvim_buf_call(buf, function()
        pcall(vim.cmd, [[
          syntax match FlutterErrorLine /^.*EXCEPTION.*$/
          syntax match FlutterErrorLine /^.*Error:.*$/
          syntax match FlutterErrorLine /^.*Exception:.*$/
          syntax match FlutterErrorLine /^.*assertion was thrown.*$/
          syntax match FlutterErrorBanner /^═.*$/
          syntax match FlutterStackTrace /#\d\+.*$/
          syntax match FlutterPackageLink /package:[a-zA-Z0-9_/]\+\.dart:\d\+\(:\d\+\)\?/

          highlight default link FlutterErrorLine DiagnosticError
          highlight default link FlutterErrorBanner DiagnosticError
          highlight default link FlutterStackTrace DiagnosticWarn
          highlight default link FlutterPackageLink Underlined
        ]])
      end)
    end

    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
      pattern = '*__FLUTTER_DEV_LOG__*',
      callback = function(ev)
        setup_flutter_log_buffer(ev.buf)
      end,
    })

    local status_timer = uv.new_timer()
    status_timer:start(1500, 1500, vim.schedule_wrap(function()
      local log_buf
      local ok_log, ft_log = pcall(require, 'flutter-tools.log')
      if ok_log and ft_log.buf and vim.api.nvim_buf_is_valid(ft_log.buf) then
        log_buf = ft_log.buf
      else
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(b)
          if name:find('__FLUTTER_DEV_LOG__', 1, true) or (name:lower():find('flutter') and name:lower():find('log')) then
            log_buf = b
            break
          end
        end
      end
      if not log_buf or not vim.api.nvim_buf_is_loaded(log_buf) then
        return
      end
      setup_flutter_log_buffer(log_buf)
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

    -- ── Flutter BLoC Widget Wrapping ──────────────────────────────────────
    local function find_matching_paren(lines, start_line, start_col)
      local depth = 0
      local in_sq = false
      local in_dq = false
      local in_comm = false

      for l = start_line, #lines do
        local line = lines[l]
        local c_start = (l == start_line) and start_col or 1
        local i = c_start
        while i <= #line do
          local ch = line:sub(i, i)
          local nch = line:sub(i + 1, i + 1)

          if in_comm then
            if ch == '*' and nch == '/' then
              in_comm = false
              i = i + 1
            end
          elseif in_sq then
            if ch == '\\' then
              i = i + 1
            elseif ch == "'" then
              in_sq = false
            end
          elseif in_dq then
            if ch == '\\' then
              i = i + 1
            elseif ch == '"' then
              in_dq = false
            end
          else
            if ch == '/' and nch == '/' then
              break
            elseif ch == '/' and nch == '*' then
              in_comm = true
              i = i + 1
            elseif ch == "'" then
              in_sq = true
            elseif ch == '"' then
              in_dq = true
            elseif ch == '(' then
              depth = depth + 1
            elseif ch == ')' then
              depth = depth - 1
              if depth == 0 then
                return l, i
              end
            end
          end
          i = i + 1
        end
      end
      return nil, nil
    end

    local function find_widgets_on_line(line)
      local widgets = {}
      local idx = 1
      while idx <= #line do
        local s, e, name = line:find('([A-Z][%w_]*)', idx)
        if not s then
          break
        end

        local pos = e + 1
        if line:sub(pos, pos) == '<' then
          local depth = 1
          local p = pos + 1
          while p <= #line and depth > 0 do
            local c = line:sub(p, p)
            if c == '<' then
              depth = depth + 1
            elseif c == '>' then
              depth = depth - 1
            end
            p = p + 1
          end
          if depth == 0 then
            pos = p
          end
        end

        if line:sub(pos, pos) == '.' then
          local ns, ne, subname = line:find('^%.([%a_][%w_]*)', pos)
          if ns then
            pos = pos + #subname + 1
          end
        end

        local after_ws = line:sub(pos):match('^%s*') or ''
        pos = pos + #after_ws

        if line:sub(pos, pos) == '(' then
          local widget_start = s
          local pre = line:sub(1, s - 1)
          local const_match = pre:match('(const%s+)$')
          if const_match then
            widget_start = s - #const_match
          end
          table.insert(widgets, {
            name = name,
            start_col = widget_start,
            name_col = s,
            open_paren_col = pos,
          })
        end
        idx = e + 1
      end
      return widgets
    end

    local function parse_constructor_args(inner)
      local args = {}
      local pdepth, bdepth, cdepth = 0, 0, 0
      local in_sq, in_dq, in_comm = false, false, false
      local cur_start = 1
      local i = 1
      while i <= #inner do
        local ch = inner:sub(i, i)
        local nch = inner:sub(i + 1, i + 1)
        if in_comm then
          if ch == '*' and nch == '/' then
            in_comm = false
            i = i + 1
          end
        elseif in_sq then
          if ch == '\\' then
            i = i + 1
          elseif ch == "'" then
            in_sq = false
          end
        elseif in_dq then
          if ch == '\\' then
            i = i + 1
          elseif ch == '"' then
            in_dq = false
          end
        else
          if ch == '/' and nch == '/' then
            local next_nl = inner:find('\n', i)
            if next_nl then
              i = next_nl
            else
              break
            end
          elseif ch == '/' and nch == '*' then
            in_comm = true
            i = i + 1
          elseif ch == "'" then
            in_sq = true
          elseif ch == '"' then
            in_dq = true
          elseif ch == '(' then
            pdepth = pdepth + 1
          elseif ch == ')' then
            pdepth = pdepth - 1
          elseif ch == '[' then
            bdepth = bdepth + 1
          elseif ch == ']' then
            bdepth = bdepth - 1
          elseif ch == '{' then
            cdepth = cdepth + 1
          elseif ch == '}' then
            cdepth = cdepth - 1
          elseif ch == ',' and pdepth == 0 and bdepth == 0 and cdepth == 0 then
            local arg = inner:sub(cur_start, i - 1)
            if vim.trim(arg) ~= '' then
              table.insert(args, vim.trim(arg))
            end
            cur_start = i + 1
          end
        end
        i = i + 1
      end
      local last_arg = inner:sub(cur_start)
      if vim.trim(last_arg) ~= '' then
        table.insert(args, vim.trim(last_arg))
      end
      return args
    end

    local function get_head(str, name)
      local s, e, base = str:find('^(' .. name .. '[%w_.]*)')
      if not s then
        return nil, nil
      end
      local pos = e + 1
      if str:sub(pos, pos) == '<' then
        local depth = 1
        local p = pos + 1
        while p <= #str and depth > 0 do
          local c = str:sub(p, p)
          if c == '<' then
            depth = depth + 1
          elseif c == '>' then
            depth = depth - 1
          end
          p = p + 1
        end
        if depth == 0 then
          pos = p
        end
      end
      local after = str:sub(pos):match('^%s*') or ''
      pos = pos + #after
      if str:sub(pos, pos) == '(' then
        return str:sub(1, pos - 1):gsub('%s*$', ''), pos
      end
      return nil, nil
    end

    local function convert_to_multi(w, single_name, multi_name, list_prop, item_template)
      local trimmed = vim.trim(w)
      local head_name, open_pos = get_head(trimmed, single_name)
      if not head_name then
        return nil
      end

      local close_pos = #trimmed
      while close_pos > open_pos and trimmed:sub(close_pos, close_pos) ~= ')' do
        close_pos = close_pos - 1
      end

      local inner = trimmed:sub(open_pos + 1, close_pos - 1)
      local args = parse_constructor_args(inner)

      local non_child_args = {}
      local child_expr = nil

      for _, arg in ipairs(args) do
        local c_match = arg:match('^child%s*:%s*(.*)$')
        if c_match then
          child_expr = c_match
        else
          table.insert(non_child_args, arg)
        end
      end

      if not child_expr then
        return nil
      end

      local first_item_args = table.concat(non_child_args, ',\n    ')
      if #first_item_args > 0 then
        first_item_args = '    ' .. first_item_args .. ','
      end

      return string.format(
        '%s(\n  %s: [\n    %s(\n%s\n    ),\n    %s,\n  ],\n  child: %s,\n)',
        multi_name,
        list_prop,
        head_name,
        first_item_args,
        item_template,
        child_expr
      )
    end

    local function get_widget_range_at(lines, cur_line, cur_col)
      -- 1. Check current line
      local ws = find_widgets_on_line(lines[cur_line] or '')
      if #ws > 0 then
        local target = nil
        for _, w in ipairs(ws) do
          local el, ec = find_matching_paren(lines, cur_line, w.open_paren_col)
          if el then
            w.end_line = el
            w.end_col = ec
            if cur_line == el then
              if cur_col >= w.start_col and cur_col <= ec then
                target = w
                break
              end
            else
              if cur_col >= w.start_col then
                target = w
                break
              end
            end
          end
        end
        if not target and ws[1].end_line then
          target = ws[1]
        end
        if target then
          return cur_line, target.start_col, target.end_line, target.end_col
        end
      end

      -- 2. Search upward for enclosing widget
      for l = cur_line - 1, math.max(1, cur_line - 50), -1 do
        local uws = find_widgets_on_line(lines[l] or '')
        for i = #uws, 1, -1 do
          local w = uws[i]
          local el, ec = find_matching_paren(lines, l, w.open_paren_col)
          if el and (el > cur_line or (el == cur_line and ec >= cur_col)) then
            return l, w.start_col, el, ec
          end
        end
      end

      return nil
    end

    local function adjust_range_and_text(buf, srow, scol, erow, ecol)
      local lines = vim.api.nvim_buf_get_text(buf, srow, scol, erow, ecol, {})
      local text = table.concat(lines, '\n')

      -- Strip leading label (e.g. "child: ", "builder: ")
      local ws_and_label = text:match('^(%s*[%a_][%w_]*%s*:%s*)')
      if ws_and_label then
        local num_newlines = 0
        local last_nl_pos = 0
        for nl in ws_and_label:gmatch('\n()') do
          num_newlines = num_newlines + 1
          last_nl_pos = nl - 1
        end
        if num_newlines > 0 then
          srow = srow + num_newlines
          scol = #ws_and_label - last_nl_pos
        else
          scol = scol + #ws_and_label
        end
        text = text:sub(#ws_and_label + 1)
      else
        local ws = text:match('^(%s+)')
        if ws then
          scol = scol + #ws
          text = text:sub(#ws + 1)
        end
      end

      -- Strip trailing commas/semicolons/whitespace
      local trailing = text:match('([,;%s]+)$')
      if trailing then
        ecol = ecol - #trailing
        text = text:sub(1, #text - #trailing)
      end

      return srow, scol, erow, ecol, text
    end

    local bloc_templates = {
      {
        name = 'BlocProvider',
        desc = 'Wrap with BlocProvider (single Bloc instance)',
        wrap = function(w)
          return string.format('BlocProvider(\n  create: (context) => SubjectBloc(),\n  child: %s,\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'MultiBlocProvider',
        desc = 'Wrap with MultiBlocProvider (or convert BlocProvider -> MultiBlocProvider)',
        wrap = function(w)
          local converted = convert_to_multi(
            w,
            'BlocProvider',
            'MultiBlocProvider',
            'providers',
            'BlocProvider(\n      create: (context) => SubjectBloc(),\n    )'
          )
          if converted then
            return converted
          end
          return string.format('MultiBlocProvider(\n  providers: [\n    BlocProvider(\n      create: (context) => SubjectBloc(),\n    ),\n  ],\n  child: %s,\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'BlocBuilder',
        desc = 'Wrap with BlocBuilder (rebuilds UI on state change)',
        wrap = function(w)
          return string.format('BlocBuilder<SubjectBloc, SubjectState>(\n  builder: (context, state) {\n    return %s;\n  },\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'BlocConsumer',
        desc = 'Wrap with BlocConsumer (builder + listener combined)',
        wrap = function(w)
          return string.format('BlocConsumer<SubjectBloc, SubjectState>(\n  listener: (context, state) {\n    // TODO: implement listener\n  },\n  builder: (context, state) {\n    return %s;\n  },\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'BlocListener',
        desc = 'Wrap with BlocListener (listens for side-effects: SnackBar, nav)',
        wrap = function(w)
          return string.format('BlocListener<SubjectBloc, SubjectState>(\n  listener: (context, state) {\n    // TODO: implement listener\n  },\n  child: %s,\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'MultiBlocListener',
        desc = 'Wrap with MultiBlocListener (or convert BlocListener -> MultiBlocListener)',
        wrap = function(w)
          local converted = convert_to_multi(
            w,
            'BlocListener',
            'MultiBlocListener',
            'listeners',
            'BlocListener<SubjectBloc, SubjectState>(\n      listener: (context, state) {\n        // TODO: implement listener\n      },\n    )'
          )
          if converted then
            return converted
          end
          return string.format('MultiBlocListener(\n  listeners: [\n    BlocListener<SubjectBloc, SubjectState>(\n      listener: (context, state) {\n        // TODO: implement listener\n      },\n    ),\n  ],\n  child: %s,\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'BlocSelector',
        desc = 'Wrap with BlocSelector (rebuilds only when selected state changes)',
        wrap = function(w)
          return string.format('BlocSelector<SubjectBloc, SubjectState, SelectedState>(\n  selector: (state) {\n    return state.property;\n  },\n  builder: (context, state) {\n    return %s;\n  },\n)', w)
        end,
        word = 'SubjectBloc',
      },
      {
        name = 'RepositoryProvider',
        desc = 'Wrap with RepositoryProvider (dependency injection)',
        wrap = function(w)
          return string.format('RepositoryProvider(\n  create: (context) => SubjectRepository(),\n  child: %s,\n)', w)
        end,
        word = 'SubjectRepository',
      },
      {
        name = 'MultiRepositoryProvider',
        desc = 'Wrap with MultiRepositoryProvider (or convert RepositoryProvider -> MultiRepositoryProvider)',
        wrap = function(w)
          local converted = convert_to_multi(
            w,
            'RepositoryProvider',
            'MultiRepositoryProvider',
            'providers',
            'RepositoryProvider(\n      create: (context) => SubjectRepository(),\n    )'
          )
          if converted then
            return converted
          end
          return string.format('MultiRepositoryProvider(\n  providers: [\n    RepositoryProvider(\n      create: (context) => SubjectRepository(),\n    ),\n  ],\n  child: %s,\n)', w)
        end,
        word = 'SubjectRepository',
      },
    }

    local function wrap_with_bloc(template_idx, ctx)
      local srow, scol, erow, ecol, widget_text

      if ctx and ctx.mode then
        -- Visual mode was used
        local s_r = ctx.srow
        local s_c = ctx.scol
        local e_r = ctx.erow
        local e_c = ctx.ecol
        if ctx.mode == 'V' then
          s_c = 0
          local last_line = vim.api.nvim_buf_get_lines(0, e_r, e_r + 1, false)[1] or ''
          e_c = #last_line
        end
        srow, scol, erow, ecol, widget_text = adjust_range_and_text(0, s_r, s_c, e_r, e_c)
      else
        local cur = (ctx and ctx.cur_line) and { ctx.cur_line, ctx.cur_col } or vim.api.nvim_win_get_cursor(0)
        local cur_line = cur[1]
        local cur_col = cur[2]
        if not (ctx and ctx.cur_col) then
          cur_col = cur_col + 1
        end

        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local sl, sc, el, ec = get_widget_range_at(lines, cur_line, cur_col)
        if sl then
          srow = sl - 1
          scol = sc - 1
          erow = el - 1
          ecol = ec
          local raw_lines = vim.api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
          widget_text = table.concat(raw_lines, '\n')
        else
          vim.notify('No Flutter widget found under cursor to wrap', vim.log.levels.WARN)
          return
        end
      end

      if not widget_text or vim.trim(widget_text) == '' then
        vim.notify('No widget found under cursor to wrap', vim.log.levels.WARN)
        return
      end

      local item = bloc_templates[template_idx]
      local wrapped = item.wrap(widget_text)
      local wrapped_lines = vim.split(wrapped, '\n')

      vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, wrapped_lines)
      local end_line = srow + #wrapped_lines
      vim.cmd(string.format('silent! normal! %dG=%dG', srow + 1, end_line))
      vim.fn.search(item.word, 'c', srow + 1)
      vim.notify('Wrapped with ' .. item.name .. '! Rename ' .. item.word .. ' (ciw).', vim.log.levels.INFO)
    end

    local function bloc_wrap_picker(ctx)
      local items = {}
      for i, t in ipairs(bloc_templates) do
        table.insert(items, string.format('%d. %s — %s', i, t.name, t.desc))
      end
      vim.ui.select(items, { prompt = 'Select BLoC Wrap Action:' }, function(choice, idx)
        if choice and idx then
          wrap_with_bloc(idx, ctx)
        end
      end)
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
        { '▶  Run App', flutter_cmd_with_status('FlutterRun', 'building', 'flutter run') },
        { '⚙  Run with Config (launch.json)', function() require('dap').continue() end },
        { '🔄 Hot Restart', flutter_cmd_with_status('FlutterRestart', 'building', 'hot restart') },
        { '⚡ Hot Reload', flutter_cmd_with_status('FlutterReload', 'building', 'hot reload') },
        { '🧱 Wrap with BLoC...', bloc_wrap_picker },
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
        { '🌐 DevTools (Browser)', 'FlutterDevTools' },
        { '🌲 Widget Tree / Outline', 'FlutterOutlineToggle' },
        { '🎨 Toggle Visual Debug', 'FlutterVisualDebug' },
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
    vim.keymap.set('n', '<leader>fo', '<cmd>FlutterOutlineToggle<CR>', { desc = 'Flutter: Widget tree outline' })
    vim.keymap.set('n', '<leader>fw', '<cmd>FlutterDevTools<CR>', { desc = 'Flutter: DevTools & Inspector' })
    vim.keymap.set('n', '<leader>fv', '<cmd>FlutterVisualDebug<CR>', { desc = 'Flutter: Visual debug guidelines' })
    vim.keymap.set('v', '<leader>cb', function()
      vim.cmd('normal! \27')
      local spos = vim.fn.getpos("'<")
      local epos = vim.fn.getpos("'>")
      local ctx = {
        srow = spos[2] - 1,
        scol = spos[3] - 1,
        erow = epos[2] - 1,
        ecol = epos[3],
        mode = vim.fn.visualmode(),
      }
      bloc_wrap_picker(ctx)
    end, { desc = 'Flutter: Wrap with BLoC' })

    vim.keymap.set('n', '<leader>cb', function()
      local cur = vim.api.nvim_win_get_cursor(0)
      bloc_wrap_picker({ cur_line = cur[1], cur_col = cur[2] + 1 })
    end, { desc = 'Flutter: Wrap with BLoC' })

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

    -- Hot Restart: <Alt+e> (recompiles and restarts the app)
    vim.keymap.set({ 'n', 'i' }, '<A-e>', function()
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
