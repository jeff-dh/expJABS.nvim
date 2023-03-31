local api = vim.api

local utils = require('jabs/utils')

local function getPreviewConfig(previewCfg)
    local mainWindowWidth = api.nvim_win_get_width(0)
    local mainWindowHeight = api.nvim_win_get_height(0)
    local pos_table = {
        top = {    pos_x = (mainWindowWidth - previewCfg.width) / 2,
                   pos_y = -previewCfg.height - 1 },
        bottom = { pos_x = (mainWindowWidth - previewCfg.width) / 2,
                   pos_y = mainWindowHeight - 1},
        right = {  pos_x = mainWindowWidth - - 1,
                   pos_y = (mainWindowHeight - previewCfg.height) / 2},
        left = {   pos_x = -previewCfg.width - 1,
                   pos_y = (mainWindowHeight - previewCfg.height) / 2 }
    }

    --[[
    if config.popup.border == 'none' then
        pos_table['top']['pos_y'] = pos_table['top']['pos_y'] - 1
        pos_table['bottom']['pos_y'] = pos_table['bottom']['pos_y'] + 1
        pos_table['right']['pos_x'] = pos_table['right']['pos_x'] + 1
        pos_table['left']['pos_x'] = pos_table['left']['pos_x'] - 1
    end
    ]]--

    return {
        width = previewCfg.width,
        height = previewCfg.height,
        row = pos_table[previewCfg.position]['pos_y'],
        col = pos_table[previewCfg.position]['pos_x'],
        style = previewCfg.style,
        border = previewCfg.border,
        anchor = "NW",
        relative = "win",
        win = api.nvim_get_current_win()
    }
end

local function open(previewCfg)
    local buf = utils.getBufferHandleFromCurrentLine()

    -- are we previewing a "deleted" buffer? If so we need to delete it
    -- again when we're done previewing!
    local deleted_buffer = utils.isDeletedBuffer(buf)

    local prev_win = api.nvim_open_win(buf, false, getPreviewConfig(previewCfg))

    api.nvim_win_set_var(prev_win, "isJABSWindow", true)
    api.nvim_set_current_win(prev_win)

    -- close preview when cursor leaves window
    local fn_callback = function()
                            api.nvim_win_close(prev_win, false)
                            if deleted_buffer then
                                vim.cmd("bd " .. buf)
                            end
                            return true
                        end
    local options = {group = "JABSAutoCmds", buffer = buf, callback = fn_callback}
    api.nvim_create_autocmd({ "WinLeave" }, options)
end

return {
    open = open
    }

