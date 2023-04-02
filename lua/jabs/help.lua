local api = vim.api

local function generateHelpText(keymap)
    local sf = string.format
    local ti = table.insert
    local lines = {}

    local km = 'KEY MAPPINGS'
    ti(lines, string.rep(' ', 20) .. km )
    ti(lines, '')

    ti(lines, sf('%15s -> Open selected buffer', keymap.jump))
    ti(lines, sf('%15s -> Open selected buffer hsplit', keymap.h_split))
    ti(lines, sf('%15s -> Open selected buffer vsplit', keymap.v_split))
    ti(lines, sf('%15s -> Open selected buffer in new tab', keymap.tab))
    ti(lines, sf('%15s -> Switch to selected buffer or open it', keymap.switch_to))
    ti(lines, sf('%15s -> Preview selected buffer', keymap.preview))
    ti(lines, sf('%15s -> Delete selected buffer or wipe it if', keymap.delete))
    ti(lines, sf('%15s    it is already deleted / unlisted', ''))
    ti(lines, sf('%15s -> Toggle show deleted buffers', keymap.toggle_unlisted))
    ti(lines, sf('%15s -> Close JABS main and help window', 'q/<ESC>'))
    ti(lines, sf('%15s -> move up', 'j/<Tab>/up'))
    ti(lines, sf('%15s -> move down', 'k/<S-Tab>/down'))
    ti(lines, '')
    ti(lines, 'Note: you must close the preview window with :q / <C-wq>')
    ti(lines, '      or similar regular closing commands')

    return lines
end

local function open(keymap)
    local ui = api.nvim_list_uis()[1]
    -- init jabs popup buffer
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "expJABS"
    api.nvim_buf_set_name(buf, "expJABS:Help")
    vim.b[buf].isJABSBuffer = true
    api.nvim_buf_set_lines(buf, 0, 0, true, generateHelpText(keymap))
    api.nvim_buf_set_option(buf, "modifiable", false)

    api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<cr>', {nowait = true, silent=true})
    api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':q<cr>', {nowait = true, silent=true})

    local width, height = 65, api.nvim_buf_line_count(buf) + 1
    local cfg = {
        width = width,
        height = height,
        row = (ui.height - height) / 2,
        col = (ui.width - width) / 2,
        border = 'single',
        anchor = "NW",
        relative = "editor",
        style = 'minimal',
    }

    local help_win = api.nvim_open_win(buf, false, cfg)

    api.nvim_win_set_var(help_win, "isJABSWindow", true)
    api.nvim_set_current_win(help_win)

    -- close help when cursor leaves window
    local fn_callback = function()
                            api.nvim_buf_delete(buf, {force = true})
                            return true
                        end
    local options = {group = "JABSAutoCmds", buffer = buf, callback = fn_callback}
    api.nvim_create_autocmd({ "WinLeave" }, options)
end

return {
    open = open
    }

