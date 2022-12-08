local api = vim.api

local function iter2array(...)
    local arr = {}
    for v in ... do
        arr[#arr + 1] = v
    end
    return arr
end

local function getUnicodeStringWidth(str)
    local extra_width = #str - #string.gsub(str, '[\128-\191]', '')
    return string.len(str) - extra_width
end

local function isJABSPopup(buf)
    return vim.b[buf].isJABSBuffer == true
end

local function getBufferHandleFromCurrentLine()
    local line = api.nvim_get_current_line()
    local handle = string.match(line, "^[^%d]*(%d+)")
    return assert(tonumber(handle))
end

local function isDeletedBuffer(buf)
    return not vim.bo[buf].buflisted and not vim.api.nvim_buf_is_loaded(buf)
end

local function getFileSymbol(filename, use_devicons, symbols)
    if not use_devicons or not pcall(require, "nvim-web-devicons") then
        return '', nil
    end

    local ext =  string.match(filename, '%.([^%.]*)$')
    local symbol, hl = require("nvim-web-devicons").get_icon(filename, ext)
    if not symbol then
        if string.match(filename, '^term://') then
            symbol = symbols.terminal
        else
            symbol = symbols.default
        end
    end

    return symbol, hl
end

local function getBufferSymbol(flags, symbols, highlight)
    local function getSymbol()
        local symbol = ''
        if string.match(flags, '%%') then
            symbol = symbols.current
        elseif string.match(flags, '#') then
            symbol = symbols.alternate
        elseif string.match(flags, 'a') then
            symbol = symbols.split
        end

        symbol = symbol .. string.rep(' ', 2- getUnicodeStringWidth(symbol))

        if string.match(flags, '-') then
            symbol = symbol .. symbols.locked
        elseif string.match(flags, '=') then
            symbol = symbol .. symbols.ro
        elseif string.match(flags, '+') then
            symbol = symbol .. symbols.edited
        end

        return symbol .. string.rep(' ', 3 - getUnicodeStringWidth(symbol))
    end

    local function getHighlight()
        if string.match(flags, '%%') then
            return highlight.current
        elseif string.match(flags, 'u') then
            return highlight.unlisted
        elseif string.match(flags, '#') then
            return highlight.alternate
        elseif string.match(flags, 'a') then
            return highlight.split
        else
            return highlight.hidden
        end
    end

    return getSymbol(), getHighlight()
end

local function formatFilename(filename, filename_max_length,
                              split_filename, split_filename_path_width)

    local function truncFilename(fn, fn_max)
        if string.len(fn) <= fn_max then
            return fn
        end

        local substr_length = fn_max - string.len("...")
        if substr_length <= 0 then
            return string.rep('.', fn_max)
        end

        return "..." .. string.sub(fn, -substr_length)
    end

    local function splitFilename(fn)
        if string.match(fn, '^Terminal: ') then
            return '', fn
        end
        return string.match(fn, "(.-)([^\\/]-%.?[^%.\\/]*)$")
    end

    -- make termial filename nicer
    filename = string.gsub(filename, "^term://(.*)//.*$", "Terminal: %1", 1)

    if split_filename then
        local path, file = splitFilename(filename)
        local path_width = split_filename_path_width
        local file_width = filename_max_length - split_filename_path_width
        filename = string.format('%-' .. file_width .. "s%-" .. path_width .. "s",
                    truncFilename(file, file_width),
                    truncFilename(path, path_width))
    else
        filename = truncFilename(filename, filename_max_length)
    end

    return string.format("%-" .. filename_max_length .. "s", filename)
end

return {
    iter2array = iter2array,
    getUnicodeStringWidth = getUnicodeStringWidth,
    isJABSPopup = isJABSPopup,
    getBufferHandleFromCurrentLine = getBufferHandleFromCurrentLine,
    isDeletedBuffer = isDeletedBuffer,
    getFileSymbol = getFileSymbol,
    getBufferSymbol = getBufferSymbol,
    formatFilename = formatFilename,
    }
