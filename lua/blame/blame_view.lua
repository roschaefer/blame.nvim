local BlameView = {}
BlameView.__index = BlameView

local parser = require("blame.parser")
local Breadcrumb = require("blame.breadcrumb")
local utils = require("blame.utils")

--- Creates a read-only scratch buffer that is wiped as soon as it is no longer displayed.
--- @return number bufnr
local function create_scratch_buffer()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	return bufnr
end

--- Sets the title of a window, escaping `%` for 'winbar'.
--- The title is never empty, because windows without a winbar would be misaligned by one row.
--- @param winid number|nil
--- @param title string
local function set_title(winid, title)
	if winid and vim.api.nvim_win_is_valid(winid) then
		local winbar = " " .. title:gsub("%%", "%%%%")
		vim.api.nvim_set_option_value("winbar", winbar, { scope = "local", win = winid })
	end
end

--- Writes lines into a read-only buffer.
--- @param bufnr number
--- @param lines string[]
local function set_lines(bufnr, lines)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Highlights the syntax of a buffer without setting its 'filetype'.
--- Setting the filetype would run ftplugins and FileType autocmds, e.g. LSP clients or plugins that
--- add virtual lines, which misalign the file content with the blame information.
--- @param bufnr number
--- @param filetype string|nil
local function highlight_syntax(bufnr, filetype)
	-- Neovim 0.10 fails to stop the highlighter if 'syntax_on' is set without the `syntaxset` autocmd group
	pcall(vim.treesitter.stop, bufnr)
	vim.bo[bufnr].syntax = ""
	if not filetype then
		return
	end

	-- Neovim 0.10 only returns explicitly registered languages, so fall back to the filetype like `vim.treesitter.start()`
	local lang = vim.treesitter.language.get_lang(filetype) or filetype
	if not pcall(vim.treesitter.start, bufnr, lang) then
		-- No tree-sitter parser is installed for this language
		vim.bo[bufnr].syntax = filetype
	end
end

function BlameView:new(dependencies)
	local instance = {
		git_instance = dependencies.git_instance,
		blame_bufnr = create_scratch_buffer(),
		file_bufnr = create_scratch_buffer(),
		blame_winid = nil,
		file_winid = nil,
		tabpage = nil,
		previous_tabpage = nil,
		augroup = nil,
		ns_id = vim.api.nvim_create_namespace("blame"),
		breadcrumb = Breadcrumb:new(),
		blame_lines = {},
	}

	setmetatable(instance, BlameView)
	return instance
end

--- Opens the view in a new tab page.
--- @return boolean mounted false if git blame failed, then nothing is opened
function BlameView:mount()
	-- Run git blame first, so a failure does not leave an empty tab page behind
	local blame_output = self.git_instance:get_blame_output(nil)
	if not blame_output then
		vim.api.nvim_buf_delete(self.blame_bufnr, { force = true })
		vim.api.nvim_buf_delete(self.file_bufnr, { force = true })
		return false
	end

	local current_file_win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(current_file_win)
	self.breadcrumb:push({ commit_info = nil, cursor_pos = cursor_pos })

	-- A new tab page leaves the user's window layout untouched
	self.previous_tabpage = vim.api.nvim_get_current_tabpage()
	vim.cmd("tab sbuffer " .. self.file_bufnr)
	self.tabpage = vim.api.nvim_get_current_tabpage()
	self.file_winid = vim.api.nvim_get_current_win()
	self.blame_winid = vim.api.nvim_open_win(self.blame_bufnr, true, {
		split = "left",
		win = self.file_winid,
		width = math.floor(vim.o.columns * 0.25),
	})

	-- Defaults only: the user config may change them for the blame window via its filetype.
	-- New windows take over the window-local options of the window `:Blame` was run from, so reset the gutter.
	vim.wo[self.blame_winid][0].cursorline = true
	vim.wo[self.file_winid][0].cursorline = true
	local blame_wo = vim.wo[self.blame_winid][0]
	blame_wo.number = false
	blame_wo.relativenumber = false
	blame_wo.statuscolumn = ""
	blame_wo.signcolumn = "no"
	blame_wo.foldcolumn = "0"
	blame_wo.list = false
	blame_wo.spell = false
	blame_wo.colorcolumn = ""
	blame_wo.winfixwidth = true
	vim.wo[self.file_winid][0].number = true
	vim.bo[self.blame_bufnr].filetype = "blame"

	self:update_view(nil, blame_output)

	utils.initialize_cursor_position(current_file_win, self.blame_winid)
	utils.initialize_cursor_position(current_file_win, self.file_winid)

	-- Closing one of the two windows (e.g. with `:q`) closes the whole view
	self.augroup = vim.api.nvim_create_augroup("blame_view_" .. self.tabpage, { clear = true })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = self.augroup,
		pattern = { tostring(self.blame_winid), tostring(self.file_winid) },
		once = true,
		callback = function()
			-- Checked right away, because Neovim switches to another tab page before the scheduled close
			local closed_in_view = vim.api.nvim_get_current_tabpage() == self.tabpage
			vim.schedule(function()
				self:close(closed_in_view)
			end)
		end,
	})
	return true
end

--- Shows the blame and file content of a version.
--- @param commit_info table|nil The line whose previous version to show, nil for the current one
--- @param blame_output string|nil The output of git blame, if it has already been run
--- @return boolean updated false if git blame failed, then the view stays unchanged
function BlameView:update_view(commit_info, blame_output)
	local blame_result_stdout = blame_output or self.git_instance:get_blame_output(commit_info)
	if not blame_result_stdout then
		return false
	end

	local blame_title = (commit_info and commit_info.previous and commit_info.previous.commit:sub(1, 8))
		or "Working tree"
	set_title(self.blame_winid, blame_title)

	local file_title
	if commit_info and commit_info.previous and commit_info.previous.filename then
		file_title = commit_info.previous.filename
	else
		file_title = self.git_instance.original_file:sub(#self.git_instance.git_root + 2)
	end
	set_title(self.file_winid, file_title)

	local blame_result = parser.parse_blame_output(blame_result_stdout)
	self.blame_lines = blame_result.lines

	local blame_content = {}
	local file_content = {}
	local commit_highlights = {}
	local previous_commit = ""
	for i, line in ipairs(self.blame_lines) do
		-- Only the first line of a block of lines from the same commit is annotated
		if line.header.commit ~= previous_commit then
			local highlight_group = "GitBlameCommit_" .. line.header.commit
			vim.api.nvim_set_hl(0, highlight_group, { fg = "#" .. line.header.commit:sub(1, 6) })
			commit_highlights[i] = highlight_group
			blame_content[i] = string.format("%s %s (%s)", line.header.commit:sub(1, 8), line.author, line.date)
			previous_commit = line.header.commit
		else
			blame_content[i] = ""
		end
		file_content[i] = line.line_content
	end

	set_lines(self.blame_bufnr, blame_content)
	set_lines(self.file_bufnr, file_content)

	vim.api.nvim_buf_clear_namespace(self.blame_bufnr, self.ns_id, 0, -1)
	for i, highlight_group in pairs(commit_highlights) do
		vim.api.nvim_buf_set_extmark(self.blame_bufnr, self.ns_id, i - 1, 0, {
			end_col = 8,
			hl_group = highlight_group,
		})
	end

	local filetype
	if commit_info and commit_info.previous and commit_info.previous.filename then
		filetype = vim.filetype.match({ filename = commit_info.previous.filename })
	else
		filetype = vim.filetype.match({ filename = self.git_instance.original_file })
	end
	highlight_syntax(self.file_bufnr, filetype)

	self:enforce_view_options()
	return true
end

--- Sets the window options the view depends on, overriding the user config.
function BlameView:enforce_view_options()
	for _, winid in ipairs({ self.blame_winid, self.file_winid }) do
		if winid and vim.api.nvim_win_is_valid(winid) then
			local wo = vim.wo[winid][0]
			wo.scrollbind = true
			wo.cursorbind = true
			-- 'scrollbind' and 'cursorbind' only sync buffer lines, not screen rows,
			-- so every buffer line has to take exactly one screen row
			wo.wrap = false
			wo.foldenable = false
			-- Diff mode adds filler lines, e.g. when `:Blame` is run from a diff window
			wo.diff = false
			-- Keeps e.g. <C-o> from replacing the blame or file buffer
			wo.winfixbuf = true
		end
	end
end

--- Moves the cursor in both windows to the same position and re-aligns their scroll views.
--- @param cursor_pos table {row, col}
function BlameView:set_cursor(cursor_pos)
	for _, winid in ipairs({ self.blame_winid, self.file_winid }) do
		utils.set_cursor_to_line(winid, cursor_pos[1])
		-- Neovim moves a column beyond the end of the line to the last character
		local row = vim.api.nvim_win_get_cursor(winid)[1]
		vim.api.nvim_win_set_cursor(winid, { row, cursor_pos[2] })
	end
	vim.api.nvim_win_call(self.file_winid, function()
		vim.cmd("syncbind")
	end)
end

function BlameView:navigate_forward()
	local line_num = vim.api.nvim_win_get_cursor(0)[1]
	local commit_info = self.blame_lines[line_num]
	if not commit_info then
		return
	end

	if not commit_info.previous then
		vim.notify("blame.nvim: No previous commit for this line (boundary commit).", vim.log.levels.INFO)
		return
	end

	local current = self.breadcrumb:current()
	if current then
		current.cursor_pos = vim.api.nvim_win_get_cursor(0)
	end

	if self.breadcrumb:push({ commit_info = commit_info, cursor_pos = nil }) then
		if not self:update_view(commit_info) then
			self.breadcrumb:pop()
			return
		end
		if commit_info and commit_info.header and commit_info.header.source_line then
			self:set_cursor({ commit_info.header.source_line, 0 })
		end
	end
end

function BlameView:navigate_backward()
	if #self.breadcrumb.stack <= 1 then
		vim.notify("blame.nvim: No more history to go back to.", vim.log.levels.INFO)
		return
	end
	local popped = self.breadcrumb:pop()
	local current = self.breadcrumb:current()
	if not self:update_view(current.commit_info) then
		self.breadcrumb:push(popped)
		return
	end

	if current.cursor_pos then
		self:set_cursor(current.cursor_pos)
	end
end

--- Closes the view and returns to the tab page it was opened from.
--- @param return_to_previous_tabpage boolean|nil Defaults to whether the view is the current tab page,
--- so closing the view from another tab page does not switch tab pages.
function BlameView:close(return_to_previous_tabpage)
	if return_to_previous_tabpage == nil then
		return_to_previous_tabpage = vim.api.nvim_get_current_tabpage() == self.tabpage
	end

	if self.augroup then
		vim.api.nvim_del_augroup_by_id(self.augroup)
		self.augroup = nil
	end

	if self.tabpage and vim.api.nvim_tabpage_is_valid(self.tabpage) then
		if #vim.api.nvim_list_tabpages() == 1 then
			-- The last tab page cannot be closed, so open an empty one to fall back to
			vim.cmd("tabnew")
		end
		vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(self.tabpage))
	end
	self.tabpage = nil

	-- `:tabclose` moves to the tab page on the right, not to the one the view was opened from
	if
		return_to_previous_tabpage
		and self.previous_tabpage
		and vim.api.nvim_tabpage_is_valid(self.previous_tabpage)
	then
		vim.api.nvim_set_current_tabpage(self.previous_tabpage)
	end
end

return BlameView
