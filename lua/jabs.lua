local M = {}
local api = vim.api

local ui = api.nvim_list_uis()[1]

require 'split'

M.opts = {
	['relative']	= 'cursor',
	['width']		= 50,
	['height']		= 10,
	['col']			= (ui.width) - 7,
	['row']			= (ui.height) - 3,
	['anchor']		= 'SE',
	['style']		= 'minimal',
	['border']		= 'shadow',
}

M.bufinfo = {
	['%a']			= {'', 'MoreMsg'},
	['#a']			= {'', 'MoreMsg'},
	['a']			= {'', 'MoreMsg'},
	['#h']			= {'', 'WarningMsg'},
	['h']			= {'﬘', 'ModeMsg'},
	['-']			= '',
	['=']			= '',
	['+']			= '',
	['R']			= '',
	['F']			= '',
}

-- Open buffer from line
function M.selBufNum(win)
	local l = api.nvim_get_current_line()
	local buf = l:split(' ', true)[4]

	vim.cmd('close')

	api.nvim_set_current_win(win)
	vim.cmd('b'..buf)
end

-- Parse ls string
function M.parseLs(bopen, buf)
	for i, b in ipairs(bopen) do
		local line = ''			-- Line to be added to buffer
		local si = 0			-- Non-empty split counter
		local highlight = ''	-- Line highlight group
		local linenr			-- Buffer line number

		for _, s in ipairs(b:split(' ', true)) do
			if s == '' then goto continue end	-- Empty splits are discarded
			si = si + 1

			-- Split with buffer information
			if si == 2 then
				_, highlight = xpcall(function()
					return M.bufinfo[s][2]
				end, function()
					return M.bufinfo[s:sub(1,s:len()-1)][2]
				end)

				local _, symbol = xpcall(function()
					return M.bufinfo[s][1]
				end, function()
					return M.bufinfo[s:sub(s:len(),s:len())]
				end)

				line = '· '..symbol..' '..line
			-- Other non-empty splits (filename, RO, modified, ...)
			else
				if s:sub(2, 8) == 'term://' then
					line = line..'Terminal'..s:gsub("^.*:", ": \"")
				else
					if tonumber(s) ~= nil and si > 2 then linenr = s else
						if s:sub(1,4) ~= 'line' then
							line = line..(M.bufinfo[s] or s)..' '
						end
					end
				end
			end

			::continue::
		end

		-- Remove quotes from filename
		line = line:gsub('\"', '')

		-- Truncate line if too long
		if line:len() > M.opts['width']-linenr:len()-3 then
			line = line:sub(1, M.opts['width']-linenr:len()-6)..'...'
		end

		-- Write line
		api.nvim_buf_set_text(buf, i, 1, i, line:len(), {line})
		api.nvim_buf_set_text(buf, i, M.opts['width']-linenr:len(), i,
							  M.opts['width'], {' '..linenr})

		api.nvim_buf_add_highlight(buf, -1, highlight, i, 0, -1)
	end
end

-- Set floating window keymaps
function M.setKeymaps(win, buf)
	-- Move to second line
	api.nvim_feedkeys('j', 'n', false)

	-- Basic window buffer configuration
	api.nvim_buf_set_option(buf, 'modifiable', false)
	api.nvim_buf_set_keymap(buf, 'n', '<CR>',
							':lua require\'jabs\'.selBufNum('..win..')<CR>',
							{ nowait = true, noremap = true, silent = true } )

	-- Navigation keymaps
	api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>',
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>',
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', '<Tab>', 'j',
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', '<S-Tab>', 'k',
							{ nowait = true, noremap = true, silent = true } )
end

-- Floating buffer list
function M.open()
	-- Get ls output for parsing
	local bopen = api.nvim_exec(':ls', true)
	bopen = bopen:split('\n', true)

	-- Create the buffer for the window
	local win = api.nvim_get_current_win()
	local buf = api.nvim_create_buf(false, true)

	api.nvim_open_win(buf, 1, M.opts)

	-- Fill buffer with right size of space
	local empty = {}
	for _ = 1, #bopen+1 do empty[#empty+1] = string.rep(' ', M.opts['width']) end
	api.nvim_buf_set_lines(buf, 0, -1, false, empty)

	-- Parse open buffers
	M.parseLs(bopen, buf)

	-- Draw title
	local title = 'Open buffers:'
	api.nvim_buf_set_text(buf, 0, 1, 0, title:len()+1, {title})
	api.nvim_buf_add_highlight(buf, -1, 'Folded', 0, 0, -1)

	M.setKeymaps(win, buf)
end

return M