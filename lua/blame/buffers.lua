local Buffers = {}
Buffers.__index = Buffers

local git = require("blame.git")
local parser = require("blame.parser")
local NuiLine = require("nui.line")
local NuiText = require("nui.text")
local Breadcrumb = require("blame.breadcrumb")

function Buffers:new(current_file_buf, blame_buf, file_buf)
	local current_file = vim.api.nvim_buf_get_name(current_file_buf)
	if not current_file or current_file == "" then
		vim.notify("blame.nvim: Not a file buffer.", vim.log.levels.WARN)
		return
	end
	-- Find git root
	local git_root = git.find_git_root(current_file)
	if not git_root then
		vim.notify("blame.nvim: Not a git repository.", vim.log.levels.WARN)
		return
	end
	local current_filetype = vim.api.nvim_get_option_value("filetype", { scope = "local", buf = current_file_buf })
	local instance = {
		current_file_buf = current_file_buf,
		current_file = current_file,
		current_filetype = current_filetype,
		git_root = git_root,
		blame_buf = blame_buf,
		file_buf = file_buf,
		ns_id = vim.api.nvim_create_namespace("blame"),
		breadcrumb = Breadcrumb:new(),
		blame_lines = {},
	}
	setmetatable(instance, Buffers)
	return instance
end

function Buffers:update_file_buffer_content(commit_hash)
	local content = git.get_file_content(self.git_root, self.current_file, commit_hash)

	if not content then
		return
	end

	vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = self.file_buf })
	vim.api.nvim_buf_set_lines(self.file_buf, 0, -1, false, content)
	vim.api.nvim_set_option_value("filetype", self.current_filetype, { scope = "local", buf = self.file_buf })
	vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.file_buf })
end

function Buffers:update_blame(commit_hash)
	local blame_result_stdout = git.get_blame_output(self.git_root, self.current_file, commit_hash)
	self.blame_lines = {}

	if not blame_result_stdout then
		return
	end

	self.blame_lines = parser.parse_blame_output(blame_result_stdout)

	vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = self.blame_buf })
	vim.api.nvim_buf_set_lines(self.blame_buf, 0, -1, false, {})

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

			nui_line:render(self.blame_buf, self.ns_id, i)
			previous_commit = line.commit
		else
			local nui_line = NuiLine({ NuiText(string.rep(" ", #blame_info_str)) })
			nui_line:render(self.blame_buf, self.ns_id, i)
		end
	end

	vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.blame_buf })
end

function Buffers:update_buffers(commit_hash)
	self:update_file_buffer_content(commit_hash)
	self:update_blame(commit_hash)
end

function Buffers:navigate_forward()
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

function Buffers:navigate_backward()
	if #self.breadcrumb.stack == 0 then
		vim.notify("blame.nvim: No more history to go back to.", vim.log.levels.INFO)
		return
	end
	self.breadcrumb:pop()
	self:update_buffers(self.breadcrumb:current())
end

return Buffers
