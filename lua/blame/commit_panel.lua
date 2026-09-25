local CommitPanel = {}
CommitPanel.__index = CommitPanel

local utils = require("blame.utils")

-- A fixed height, so the windows above do not change their height whenever the cursor moves to another commit
local HEIGHT = 10

function CommitPanel:new(dependencies)
	local bufnr = utils.create_scratch_buffer()
	-- Kept while the panel is closed, so keymaps added to it survive toggling
	vim.bo[bufnr].bufhidden = "hide"

	local instance = {
		git_instance = dependencies.git_instance,
		bufnr = bufnr,
		winid = nil,
		commit = nil,
		messages = {},
	}

	setmetatable(instance, CommitPanel)
	return instance
end

--- @return boolean
function CommitPanel:is_open()
	return self.winid ~= nil and vim.api.nvim_win_is_valid(self.winid)
end

--- Opens the panel at the bottom of the tab page, without entering it.
--- @param commit string The commit hash whose message to show.
function CommitPanel:open(commit)
	if not self:is_open() then
		-- Set on first open, after the keymaps of blame.nvim, so keymaps of the user config for it take precedence
		if vim.bo[self.bufnr].filetype ~= "git" then
			vim.bo[self.bufnr].filetype = "git"
		end
		self.winid = vim.api.nvim_open_win(self.bufnr, false, { split = "below", win = -1, height = HEIGHT })
		self.commit = nil

		-- New windows take over the window-local options of the current window, e.g. 'scrollbind' of the blame view
		local wo = vim.wo[self.winid][0]
		wo.scrollbind = false
		wo.cursorbind = false
		wo.cursorline = false
		wo.wrap = true
		wo.winbar = ""
		wo.number = false
		wo.relativenumber = false
		wo.statuscolumn = ""
		wo.signcolumn = "no"
		wo.foldcolumn = "0"
		wo.colorcolumn = ""
		wo.diff = false
		wo.winfixbuf = true
		wo.winfixheight = true
	end
	self:show(commit)
end

--- Closes the panel. If the cursor is in the panel, it returns to the window it came from.
function CommitPanel:close()
	if self:is_open() then
		if vim.api.nvim_get_current_win() == self.winid then
			vim.cmd("wincmd p")
		end
		vim.api.nvim_win_close(self.winid, true)
	end
	self.winid = nil
	self.commit = nil
end

--- Closes the panel and deletes its buffer.
function CommitPanel:destroy()
	self:close()
	if vim.api.nvim_buf_is_valid(self.bufnr) then
		vim.api.nvim_buf_delete(self.bufnr, { force = true })
	end
end

--- @param commit string The commit hash whose message to show when opening the panel.
function CommitPanel:toggle(commit)
	if self:is_open() then
		self:close()
	else
		self:open(commit)
	end
end

--- Shows the message of a commit, if the panel is open.
--- @param commit string|nil The commit hash.
function CommitPanel:show(commit)
	if not commit or not self:is_open() or commit == self.commit then
		return
	end
	self.commit = commit
	utils.set_lines(self.bufnr, self:get_message(commit))
	vim.api.nvim_win_set_cursor(self.winid, { 1, 0 })
end

--- @param commit string The commit hash.
--- @return string[]
function CommitPanel:get_message(commit)
	-- Uncommitted lines have an all-zero hash, 40 characters long for SHA-1 and 64 for SHA-256
	if commit:match("^0+$") then
		return { "Not committed yet" }
	end
	if not self.messages[commit] then
		-- Failures are not cached, so git runs again the next time the commit is shown
		local message = self.git_instance:get_commit_message(commit)
		if not message then
			return {}
		end
		self.messages[commit] = message
	end
	return self.messages[commit]
end

return CommitPanel
