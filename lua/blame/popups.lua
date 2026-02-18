local Popups = {}
Popups.__index = Popups

local parser = require("blame.parser")
local NuiLine = require("nui.line")
local NuiText = require("nui.text")
local Breadcrumb = require("blame.breadcrumb")

function Popups:new(dependencies, current_file_buf)
	local git_instance = dependencies.git_instance
	local blame_popup_instance = dependencies.blame_popup_instance
	local file_popup_instance = dependencies.file_popup_instance

	local current_filetype = vim.api.nvim_get_option_value("filetype", { scope = "local", buf = current_file_buf })
	local instance = {
		current_file_buf = current_file_buf,
		git_instance = git_instance,
		current_filetype = current_filetype,
		blame_popup_instance = blame_popup_instance,
		file_popup_instance = file_popup_instance,
		ns_id = vim.api.nvim_create_namespace("blame"),
		breadcrumb = Breadcrumb:new(),
		blame_lines = {},
	}
	setmetatable(instance, Popups)
	return instance
end

function Popups:update_file_buffer_content(commit_hash)
	local content = self.git_instance:get_file_content(commit_hash)

	if not content then
		return
	end

	vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = self.file_popup_instance.bufnr })
	vim.api.nvim_buf_set_lines(self.file_popup_instance.bufnr, 0, -1, false, content)
	vim.api.nvim_set_option_value(
		"filetype",
		self.current_filetype,
		{ scope = "local", buf = self.file_popup_instance.bufnr }
	)
	vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.file_popup_instance.bufnr })
end

function Popups:update_blame(commit_hash)
	local blame_result_stdout = self.git_instance:get_blame_output(commit_hash)
	self.blame_lines = {}

	if not blame_result_stdout then
		return
	end

	self.blame_lines = parser.parse_blame_output(blame_result_stdout)

	vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = self.blame_popup_instance.bufnr })

	local previous_commit = ""
	for i, line in ipairs(self.blame_lines) do
		local blame_info_str = string.format("%s %s (%s)", line.commit, line.author, line.date)
		if line.commit ~= previous_commit then
			local hex_color = "#" .. line.commit:sub(1, 6)
			local highlight_group = "GitBlameCommit_" .. line.commit
			vim.cmd("highlight " .. highlight_group .. " guifg=" .. hex_color)

			local commit_text = NuiText(line.commit:sub(1, 8), highlight_group)
			local author_and_date_text = NuiText(" " .. line.author .. " (" .. line.date .. ")")

			local nui_line = NuiLine({
				commit_text,
				author_and_date_text,
			})

			nui_line:render(self.blame_popup_instance.bufnr, self.ns_id, i)
			previous_commit = line.commit
		else
			local nui_line = NuiLine({ NuiText(string.rep(" ", #blame_info_str)) })
			nui_line:render(self.blame_popup_instance.bufnr, self.ns_id, i)
		end
	end

	vim.api.nvim_buf_set_lines(self.blame_popup_instance.bufnr, #self.blame_lines + 1, -1, false, {})
	vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.blame_popup_instance.bufnr })
end

function Popups:update_buffers(commit_hash)
	local title = commit_hash or "working tree"
	self.file_popup_instance.border:set_text("top", title)
	self:update_file_buffer_content(commit_hash)
	self:update_blame(commit_hash)
end

function Popups:navigate_forward()
	local line_num = vim.api.nvim_win_get_cursor(0)[1]
	local commit_info = self.blame_lines[line_num]
	if not commit_info then
		return
	end
	local new_commit_hash = commit_info.commit

	if self.breadcrumb:push(new_commit_hash) then
		self:update_buffers(self.breadcrumb:current())
	end
end

function Popups:navigate_backward()
	if #self.breadcrumb.stack == 0 then
		vim.notify("blame.nvim: No more history to go back to.", vim.log.levels.INFO)
		return
	end
	self.breadcrumb:pop()
	self:update_buffers(self.breadcrumb:current())
end

return Popups
