
local config = {}

local function setup(c)
    -- create empty default tables for missing config tables
    c = c or {}
    c.offset = c.offset or {}
    c.symbols = c.symbols or {}
    c.keymap = c.keymap or {}
    c.preview = c.preview or {}
    c.highlight = c.highlight or {}
    c.offset = c.offset or {}
    c.openCommands = c.openCommands or {}

    -- position backwards compatibility
    if c.position == 'center' then
        c.position = {'center', 'center'}
    elseif c.position == 'corner' then
        c.position = {'right', 'bottom'}
    end

    -- main popup window stuff
    config.popup = {
        position = c.position or {'center', 'top'},
        width = c.width or 50,
        height = c.height or 10,
        relative = c.relative or 'win',
        border = c.border or 'single',
        clip_size = not (c.clip_popup_size == false),

        top_offset = c.offset.top or 0,
        bottom_offset = c.offset.bottom or 0,
        left_offset = c.offset.left or 0,
        right_offset = c.offset.right or 0,
    }

    config.preview = {
        width = c.preview.width or 70,
        height = c.preview.height or 30,
        style = c.preview.style or nil,
        border = c.preview.border or "double",
        position = c.preview_position or "top",
    }

    config.keymap = {
        delete = c.keymap.close or "D",
        jump = c.keymap.jump or "<CR>",
        h_split = c.keymap.h_split or "s",
        v_split = c.keymap.v_split or "v",
        preview = c.keymap.preview or "P",
        toggle_unlisted = c.keymap.toggle_unlisted or "u",
        switch_to = c.keymap.switch_to or "<S-CR>",
        tab = c.keymap.tab or "t",
    }

    -- sort_mru and split_filename
    config.sort_mru = not (c.sort_mru == false)
    config.split_filename = c.split_filename or false
    config.split_filename_path_width = c.split_filename_path_width or 0

    -- icon / symbol stuff
    config.use_devicons = not (c.use_devicons == false)

    config.disable_title = c.disable_title or false

    config.highlight = {
        current = c.highlight.current or "Number",
        split = c.highlight.split or "Statement",
        alternate = c.highlight.alternate or "Function",
        hidden = c.highlight.hidden or "String",
        unlisted = c.highlight.unlisted or "ErrorMsg",
        filename = c.highlight.filename or nil
    }

    config.symbols = {
        default = c.symbols.default_file or "",
        current = c.symbols.current or "",
        split = c.symbols.split or "",
        alternate = c.symbols.alternate or "",
        locked = c.symbols.locked or "",
        ro = c.symbols.ro or "",
        edited = c.symbols.edited or "",
        terminal = c.symbols.terminal or "",
    }

    config.openCommands = {
        window = c.openCommands.window or "b%s",
        vsplit = c.openCommands.vsplit or "vert sb %s",
        hsplit = c.openCommands.hsplit or "sb %s",
        tab = c.openCommands.tab or "tab sb %s",
    }
end

config.setup = setup

return config

