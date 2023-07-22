local api = vim.api
---@diagnostic disable-next-line: deprecated
local unpack = (table.unpack or unpack)

local utils = require('jabs/utils')
local config = require('jabs/config')
local preview = require('jabs/preview')
local help = require('jabs/help')

local function closePopup()
    local window_handle = api.nvim_get_current_win()
    assert(vim.w[window_handle].isJABSWindow)
    api.nvim_win_close(window_handle, false)
    -- all the cleanup will be done by cleanUp which gets
    -- call by the WinClosed event
end

local function cleanUp()
    -- create -- without clearing -- JABSAutoCmds to ensure it exists when we
    -- clear it. Otherwise -> Exception
    api.nvim_create_augroup("JABSAutoCmds", {clear=false})
    api.nvim_clear_autocmds({group = "JABSAutoCmds"})

    local callerWinId
    for _, win in ipairs(api.nvim_list_wins()) do
        if vim.w[win].isJABSWindow == true then
            if vim.w[win].JABSCallerWinId then
                callerWinId = vim.w[win].JABSCallerWinId
            end
            api.nvim_win_close(win, false)
        end
    end
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if vim.b[buf].isJABSBuffer == true then
            api.nvim_buf_delete(buf, {force = false})
        end
    end

    if callerWinId then
        api.nvim_set_current_win(callerWinId)
    end
end

local function getLSResult()
    local function parentWinCall(fn)
        -- execute a command in the parent window
        return vim.api.nvim_win_call(vim.w.JABSCallerWinId, fn)
    end

    -- build ls command
    local ls_cmd = ":ls"
    if vim.w.show_unlisted then ls_cmd = ls_cmd .. "!" end
    if config.sort_mru then  ls_cmd = ls_cmd .. " t" end

    --execute ls command and split by '\n'
    --this is a little tricky, we need to call the ls command from the
    --previous window (not the JABS window) to get the right results
    local ls_call = function () return api.nvim_exec(ls_cmd, true) end
    local ls_result = parentWinCall(ls_call)
    local ls_lines = utils.iter2array(string.gmatch(ls_result, "([^\n]+)"))


    local result = {}
    for _, ls_line in ipairs(ls_lines) do
        -- extract data from ls string
        local match_cmd = '(%d+)(.*)"(.*)"'
        if not config.sort_mru then
            match_cmd = match_cmd .. '%s*%a+%s(%d+)'
        else
            -- dummy that should never match so we get '' as result for linenr
            match_cmd = match_cmd .. '(\n?)'
        end

        local buffer_handle_s, flags, filename, linenr_s =
            string.match(ls_line, match_cmd)

        local buffer_handle = assert(tonumber(buffer_handle_s))
        local linenr = linenr_s == '' and -1 or assert(tonumber(linenr_s))
        flags = string.gsub(flags, '%s', '')

        -- all "regulare unlisted buffers" are not loaded
        -- loaded and unlisted buffers are usually hidden plugin buffers
        local unlisted = string.match(flags, 'u')
        local loaded = api.nvim_buf_is_loaded(buffer_handle)
        if not (unlisted and loaded) then
            table.insert(result, {buffer_handle, flags, filename, linenr})
        end
    end

    return result
end

local function updateBufferFromLsLines(buf)

    for i, ls_line in ipairs(getLSResult()) do
        local buffer_handle, flags, filename, linenr = unpack(ls_line)

        -- get file and buffer symbol
        local fn_symbol, fn_symbol_hl =
            utils.getFileSymbol(filename, config.use_devicons, config.symbols)
        local buf_symbol, buf_symbol_hl =
            utils.getBufferSymbol(flags, config.symbols, config.highlight)

        -- format preLine and postLine
        local preLine =
            string.format("%s %3d %s ", buf_symbol, buffer_handle, fn_symbol)
        local postLine = linenr >= 0 and string.format("  %3d ", linenr) or ''

        -- determine filename field length and format filename
        local buffer_width = api.nvim_win_get_width(0)
        local filename_max_length =
            buffer_width - vim.fn.strchars(preLine .. postLine)
        local filename_str = utils.formatFilename(filename, filename_max_length,
                                                  config.split_filename,
                                                  config.split_filename_path_width)

        -- concat final line for the buffer
        local line = preLine .. filename_str .. postLine

        -- add line to buffer
        local new_line = config.disable_title and i - 1 or i
        api.nvim_buf_set_lines(buf, new_line, -1, true, { line })
        --apply some highlighting
        api.nvim_buf_add_highlight(buf, -1, buf_symbol_hl, new_line, 0, -1)

        -- highligh filename
        if config.highlight.filename ~= nil then
            local fn = string.match(filename, '/([^/]*)$')
            if fn == nil then
                fn = string.gsub(filename, "%[", "%%[")
                fn = string.gsub(fn, "%]", "%%]")
            end
            local fn_start, fn_end
            if not config.split_filename then
                fn_start, fn_end = string.match(line, '/()' .. fn .. '()[^%/]*$')
            else
                fn_start, fn_end = string.match(line, '^[^/]*()' .. fn .. '()')
            end

            -- there's a special case when split_filename is true and the
            -- filename itself gets truncated, in that case we simply can't
            -- find the filename -> fn_start is nil in that case
            if fn_start ~= nil then
                api.nvim_buf_add_highlight(buf, -1, config.highlight.filename,
                                           new_line, fn_start-1, fn_end)
            end
        end
        -- highlight file type symbol
        if fn_symbol_hl and fn_symbol ~= '' then
            local pos = string.find(line, fn_symbol, 1, true)
            api.nvim_buf_add_highlight(buf, -1, fn_symbol_hl, new_line, pos,
                                       pos + string.len(fn_symbol) - 1)
        end
    end
end

local function refresh()
    local function setTitle(buf)
        if config.disable_title then
            return
        end

        local w = api.nvim_win_get_width(0)
        local h = utils.fitIntoWidth('press ? for help', w-1, false)
        api.nvim_buf_set_lines(buf, 0, -1, false, {h})
        local open = 'Open Buffers:'
        api.nvim_buf_set_text(buf, 0, 0, 0, #open, {open})
        api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, #open)
    end
    --save cursor position
    local cursor_pos = vim.fn.getpos('.')

    local buf = api.nvim_get_current_buf()
    assert(utils.isJABSPopup(buf))

    -- init buffer
    api.nvim_buf_set_option(buf, "modifiable", true)
    setTitle(buf)

    updateBufferFromLsLines(buf)

    -- Disable modifiable when done
    api.nvim_buf_set_option(buf, "modifiable", false)
    -- restore cursor position
    vim.fn.setpos('.', cursor_pos)
end

local function openSelectedBuffer(opt)
    local buf = vim.v.count
    if buf == 0 then
        buf = utils.getBufferHandleFromCurrentLine()
    end

    if vim.fn.bufexists(buf) == 0 then
        print("Buffer number not found!")
        return
    end

    closePopup()

    local openOptions = {
        window = "b%s",
        vsplit = "vert sb %s",
        hsplit = "sb %s",
        tab = "tab sb %s",
    }

    -- explicitly set the buflisted flag. This "restores" deleted buffers
    vim.bo[buf].buflisted = true
    vim.cmd(string.format(openOptions[opt], buf))
end

local function deleteSelectedBuffer()
    local buf = utils.getBufferHandleFromCurrentLine()

    -- if buffer is already delete or is modified, we can't delete it
    if vim.bo[buf].mod then
        print("Can't delete buffer!")
        return
    end

    -- check if file is open in a window
    local buf_win_id = unpack(vim.fn.win_findbuf(buf))
    if buf_win_id ~= nil then return end

    if not utils.isDeletedBuffer(buf) then
        vim.cmd("bd " .. buf)
    else
        vim.cmd("bw " .. buf)
    end
    refresh()
end

local function switchToSelectedBuffer()
    local buf = utils.getBufferHandleFromCurrentLine()
    local buf_win_id = unpack(vim.fn.win_findbuf(buf))

    if buf_win_id ~= nil then
        -- set JABSCallerWinId to buf_win_id, the cleanup function will set the
        -- callerWinId as current win.....
        vim.w.JABSCallerWinId = buf_win_id
        closePopup()
    else
        openSelectedBuffer('window')
    end
end

local function setKeymaps(buf)

    local function buf_keymap(key, fn_callback)
        api.nvim_buf_set_keymap(buf, "n", key, '',
            {nowait = true, noremap = true, silent = true,
             callback = fn_callback})
    end

    local function winEnterEvent()
        ---@diagnostic disable-next-line: undefined-field
        if vim.w.isJABSWindow ~= true then
            cleanUp()
        end
    end

    local function toggleUnlisted()
        vim.w.show_unlisted = not vim.w.show_unlisted
        refresh()
    end

    -- Basic window buffer configuration
    buf_keymap('<2-LeftMouse>',
               function() openSelectedBuffer("window") end)
    buf_keymap(config.keymap.jump,
               function() openSelectedBuffer("window") end)
    buf_keymap(config.keymap.h_split,
               function() openSelectedBuffer("hsplit") end)
    buf_keymap(config.keymap.v_split,
               function() openSelectedBuffer("vsplit") end)
    buf_keymap(config.keymap.tab,
               function() openSelectedBuffer("tab") end)
    buf_keymap(config.keymap.preview,
               function() preview.open(config.preview) end)
    buf_keymap(config.keymap.switch_to,
               function() switchToSelectedBuffer() end)
    buf_keymap('?', function() help.open(config.keymap) end)
    buf_keymap(config.keymap.delete, deleteSelectedBuffer)
    buf_keymap(config.keymap.toggle_unlisted, toggleUnlisted)

    -- Navigation keymaps
    buf_keymap("q", closePopup)
    buf_keymap("<Esc>", closePopup)

    local options = { nowait = true, noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, "n", "<Tab>", "j",options)
    api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "k", options)

    -- some auto commands to handle closing JABS
    api.nvim_create_augroup("JABSAutoCmds", {})
    api.nvim_create_autocmd({'WinEnter'}, {group="JABSAutoCmds",
                                           callback = winEnterEvent})

    local win = api.nvim_get_current_win()
    api.nvim_create_autocmd({'WinClosed'}, {pattern=tostring(win),
                                            group="JABSAutoCmds",
                                            callback = cleanUp})
end

local function getPopupConfig()
    assert(type(config.popup.position) == 'table')
    assert(#config.popup.position == 2)

    local position_x, position_y = unpack(config.popup.position)
    local relative = config.popup.relative

    -- determine max width and height (-2 -> border)
    local max_width, max_height
    if relative == 'win' then
        max_width = api.nvim_win_get_width(0) - 2
        max_height = api.nvim_win_get_height(0) - 2
    elseif relative == 'editor' or relative == 'cursor' then
        local ui = api.nvim_list_uis()[1]
        max_width = ui.width - 2
        max_height = ui.height - 2
    else assert(false)
    end

    -- clip size if neccessary
    local size_x, size_y = config.popup.width, config.popup.height
    if config.popup.clip_size then
        size_x = size_x > max_width and max_width or config.popup.width
        size_y = size_y > max_height and max_height or config.popup.height
    end

    local pos_table = {
        cursor = { pos_x = { center = -size_x / 2,
                             right  = 0 + config.popup.left_offset,
                             left   = -size_x - config.popup.right_offset, },
                   pos_y = { center = -size_y / 2,
                             bottom = 0 + config.popup.top_offset,
                             top    = -size_y - config.popup.bottom_offset, },
        },
        win = { pos_x = { center = max_width / 2 - size_x / 2,
                          right  = max_width - size_x - config.popup.right_offset,
                          left   = 0 + config.popup.left_offset, },
                pos_y = { center = max_height / 2 - size_y / 2,
                          bottom = max_height - size_y - config.popup.bottom_offset,
                          top    = 0 + config.popup.top_offset, },
        },
    }
    pos_table.editor = pos_table.win

    return {
        width = size_x,
        height = size_y,
        row = pos_table[relative]["pos_y"][position_y],
        col = pos_table[relative]["pos_x"][position_x],
        style ='minimal',
        border = config.popup.border,
        anchor = "NW",
        relative = config.popup.relative,
    }

end

local function open()
    local current_buf = api.nvim_get_current_buf()

    if utils.isJABSPopup(current_buf) then
        closePopup()
        return
    end

    cleanUp()

    local JABSCallerWinId = api.nvim_get_current_win()

    -- init jabs popup buffer
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "expJABS"
    api.nvim_buf_set_name(buf, "expJABS")
    vim.b[buf].isJABSBuffer = true

    -- Prevent cursor from going to buffer title
    if not config.disable_title then
        vim.cmd(string.format(
            "au CursorMoved <buffer=%s> if line(\".\") == 1 | call feedkeys('j', 'n') | endif",
            buf))
    end

    api.nvim_open_win(buf, true, getPopupConfig())
    vim.w.isJABSWindow = true
    vim.w.JABSCallerWinId = JABSCallerWinId
    vim.w.show_unlisted = false

    refresh()
    setKeymaps(buf)
end

return { open = open, setup = config.setup }

