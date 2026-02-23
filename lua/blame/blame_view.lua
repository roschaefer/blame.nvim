local BlameView = {}
BlameView.__index = BlameView

local Popup = require("nui.popup")
local Layout = require("nui.layout")

local parser = require("blame.parser")
local NuiLine = require("nui.line")
local NuiText = require("nui.text")
local Breadcrumb = require("blame.breadcrumb")
local utils = require("blame.utils")

function BlameView:new(dependencies)
	local git_instance = dependencies.git_instance

	-- Create blame_popup for blame information
	local blame_popup_instance = Popup({
		border = {
			style = "rounded",
			text = {
				top = "",
			},
		},
		focusable = true,
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			number = false,
			relativenumber = false,
			cursorline = true,
			wrap = false,
			winfixwidth = true,
		},
	})

	-- Create file_popup for file content
	local file_popup_instance = Popup({
		border = {
			style = "rounded",
			text = {
				top = "",
			},
		},
		focusable = true,
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			number = true,
			relativenumber = true,
			cursorline = true,
			wrap = false,
		},
	})

	local instance = {
		git_instance = git_instance,
		blame_popup_instance = blame_popup_instance,
		file_popup_instance = file_popup_instance,
		ns_id = vim.api.nvim_create_namespace("blame"),
		breadcrumb = Breadcrumb:new(),
		blame_lines = {},
	}

	-- Define the layout: blame_popup on left, file_popup on right
	instance.layout = Layout(
		{ relative = "editor", position = "50%", size = "90%" }, -- Options for the main layout
		Layout.Box({
			Layout.Box(blame_popup_instance, { size = "25%" }), -- Pass popup directly as component
			Layout.Box(file_popup_instance, { size = "75%" }), -- Pass popup directly as component
		}, { dir = "row" })
	)

	setmetatable(instance, BlameView)
	return instance
end

function BlameView:mount()
	local current_file_win = vim.api.nvim_get_current_win()
	self.layout:mount()

	-- Set current window to the blame popup for initial blame display
	if self.blame_popup_instance and self.blame_popup_instance.winid then
		vim.api.nvim_set_current_win(self.blame_popup_instance.winid)
	end

	utils.initialize_cursor_position(current_file_win, self.blame_popup_instance.winid)
	utils.initialize_cursor_position(current_file_win, self.file_popup_instance.winid)

	local popups_list = {
		self.blame_popup_instance,
		self.file_popup_instance,
	}
	for _, popup in pairs(popups_list) do
		popup:on("BufLeave", function()
			vim.schedule(function()
				local curr_bufnr = vim.api.nvim_get_current_buf()
				for _, p in pairs(popups_list) do
					if p.bufnr == curr_bufnr then
						return
					end
				end
				self.layout:unmount()
			end)
		end)
	end
end

function BlameView:update_view(commit_info)
	local blame_result_stdout = self.git_instance:get_blame_output(commit_info)
	self.blame_lines = {}

	if not blame_result_stdout then
		return
	end

	local blame_title = (commit_info and commit_info.previous and commit_info.previous.commit:sub(1, 8)) or ""
	self.blame_popup_instance.border:set_text("top", blame_title)

	local file_title
	if commit_info and commit_info.previous and commit_info.previous.filename then
		file_title = commit_info.previous.filename
	else
		file_title = self.git_instance.original_file:sub(#self.git_instance.git_root + 2)
	end
	self.file_popup_instance.border:set_text("top", file_title)

	local blame_result = parser.parse_blame_output(blame_result_stdout)
	self.blame_lines = blame_result.lines

	vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = self.blame_popup_instance.bufnr })
	vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = self.file_popup_instance.bufnr })

	local previous_commit = ""
	for i, line in ipairs(self.blame_lines) do
		-- Blame Popup Rendering
		local blame_info_str = string.format("%s %s (%s)", line.header.commit, line.author, line.date)
		if line.header.commit ~= previous_commit then
			local hex_color = "#" .. line.header.commit:sub(1, 6)
			local highlight_group = "GitBlameCommit_" .. line.header.commit
			vim.cmd("highlight " .. highlight_group .. " guifg=" .. hex_color)

			local commit_text = NuiText(line.header.commit:sub(1, 8), highlight_group)
			local author_and_date_text = NuiText(" " .. line.author .. " (" .. line.date .. ")")

			local blame_nui_line = NuiLine({
				commit_text,
				author_and_date_text,
			})

			blame_nui_line:render(self.blame_popup_instance.bufnr, self.ns_id, i)
			previous_commit = line.header.commit
		else
			local blame_nui_line = NuiLine({ NuiText(string.rep(" ", #blame_info_str)) })
			blame_nui_line:render(self.blame_popup_instance.bufnr, self.ns_id, i)
		end

		-- File Popup Rendering
		local file_nui_line = NuiLine({ NuiText(line.line_content) })
		file_nui_line:render(self.file_popup_instance.bufnr, self.ns_id, i)
	end

	-- Clear remaining lines in both buffers
	vim.api.nvim_buf_set_lines(self.blame_popup_instance.bufnr, #self.blame_lines, -1, false, {})
	vim.api.nvim_buf_set_lines(self.file_popup_instance.bufnr, #self.blame_lines, -1, false, {})

	-- Set filetype for highlighting
	local filetype
	if commit_info and commit_info.previous and commit_info.previous.filename then
		filetype = vim.filetype.match({ filename = commit_info.previous.filename })
	else
		filetype = vim.filetype.match({ filename = self.git_instance.original_file })
	end

	if filetype then
		vim.api.nvim_set_option_value("filetype", filetype, { scope = "local", buf = self.file_popup_instance.bufnr })
	end

	vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.blame_popup_instance.bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.file_popup_instance.bufnr })
end

function BlameView:update_buffers(commit_info)
	self:update_view(commit_info)
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

	if self.breadcrumb:push(commit_info) then
		local current = self.breadcrumb:current()
		self:update_buffers(current)
	end
end

function BlameView:navigate_backward()
	if #self.breadcrumb.stack == 0 then
		vim.notify("blame.nvim: No more history to go back to.", vim.log.levels.INFO)
		return
	end
	self.breadcrumb:pop()
	local current = self.breadcrumb:current()
	self:update_buffers(current)
end

function BlameView:close()
	self.layout:unmount()
end

function BlameView:switch_focus()
	local current_win = vim.api.nvim_get_current_win()
	if current_win == self.blame_popup_instance.winid then
		vim.api.nvim_set_current_win(self.file_popup_instance.winid)
	else
		vim.api.nvim_set_current_win(self.blame_popup_instance.winid)
	end
end

return BlameView
