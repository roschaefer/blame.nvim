-- tests/blame/commit_panel_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local CommitPanel = require("blame.commit_panel")

describe("blame.commit_panel", function()
	local snapshot
	local mock_git
	before_each(function()
		snapshot = assert:snapshot()
		mock_git = {
			get_commit_message = stub({}, "get_commit_message", function(_, commit)
				return { "commit " .. commit, "", "    Subject of " .. commit }
			end),
		}
	end)

	after_each(function()
		snapshot:revert()
	end)

	it("opens the commit message at the bottom without entering it", function()
		local current_winid = vim.api.nvim_get_current_win()
		local panel = CommitPanel:new({ git_instance = mock_git })

		panel:open("abc123")

		assert.is_true(panel:is_open())
		assert.are.equal(current_winid, vim.api.nvim_get_current_win())
		assert.are.same({ "col", { { "leaf", current_winid }, { "leaf", panel.winid } } }, vim.fn.winlayout())
		assert.are.same(
			{ "commit abc123", "", "    Subject of abc123" },
			vim.api.nvim_buf_get_lines(panel.bufnr, 0, -1, false)
		)
		assert.are.equal("git", vim.bo[panel.bufnr].filetype)
		assert.is_false(vim.bo[panel.bufnr].modifiable)

		panel:destroy()
	end)

	it(
		"keeps its height when the cursor moves to a commit with a shorter message, so the windows above do not jump",
		function()
			mock_git.get_commit_message = stub({}, "get_commit_message", function(_, commit)
				if commit == "long" then
					return vim.split(string.rep("line\n", 15), "\n", { trimempty = true })
				end
				return { "commit " .. commit }
			end)
			local panel = CommitPanel:new({ git_instance = mock_git })
			panel:open("long")
			assert.are.equal(10, vim.api.nvim_win_get_height(panel.winid))

			panel:show("short")

			assert.are.equal(10, vim.api.nvim_win_get_height(panel.winid))
			assert.is_true(vim.wo[panel.winid].winfixheight)

			panel:destroy()
		end
	)

	it("does not take over the scroll binding and winbar of the current window", function()
		vim.wo.scrollbind = true
		vim.wo.cursorbind = true
		vim.wo.winbar = " title"
		local panel = CommitPanel:new({ git_instance = mock_git })

		panel:open("abc123")

		assert.is_false(vim.wo[panel.winid].scrollbind)
		assert.is_false(vim.wo[panel.winid].cursorbind)
		assert.are.equal("", vim.wo[panel.winid].winbar)

		panel:close()
		vim.wo.scrollbind = false
		vim.wo.cursorbind = false
		vim.wo.winbar = ""
	end)

	it("is not a preview window, so preview commands like `:pedit` and `:pclose` leave it alone", function()
		local panel = CommitPanel:new({ git_instance = mock_git })
		panel:open("abc123")

		vim.cmd("pedit README.md")

		assert.is_false(vim.wo[panel.winid].previewwindow)
		assert.are.equal(panel.bufnr, vim.api.nvim_win_get_buf(panel.winid))

		vim.cmd("pclose")

		assert.is_true(panel:is_open())

		panel:destroy()
		vim.cmd("bwipeout README.md")
	end)

	it("closes with `:quit` from inside", function()
		local panel = CommitPanel:new({ git_instance = mock_git })
		panel:open("abc123")
		vim.api.nvim_set_current_win(panel.winid)

		vim.cmd("quit")

		assert.is_false(panel:is_open())

		panel:destroy()
	end)

	it("returns the cursor to the window it came from when it is closed from inside", function()
		vim.cmd("vsplit")
		local previous_winid = vim.api.nvim_get_current_win()
		local panel = CommitPanel:new({ git_instance = mock_git })
		panel:open("abc123")
		vim.api.nvim_set_current_win(panel.winid)

		panel:close()

		assert.are.equal(previous_winid, vim.api.nvim_get_current_win())

		panel:destroy()
		vim.cmd("close")
	end)

	it("keeps its buffer while it is closed and deletes it when it is destroyed", function()
		local panel = CommitPanel:new({ git_instance = mock_git })
		local bufnr = panel.bufnr
		panel:open("abc123")

		panel:close()

		assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
		panel:open("abc123")
		assert.are.equal(bufnr, vim.api.nvim_win_get_buf(panel.winid))

		panel:destroy()

		assert.is_false(panel:is_open())
		assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
	end)

	it("toggles between open and closed", function()
		local panel = CommitPanel:new({ git_instance = mock_git })

		panel:toggle("abc123")
		assert.is_true(panel:is_open())

		panel:toggle("abc123")
		assert.is_false(panel:is_open())
		assert.are.equal(1, #vim.api.nvim_tabpage_list_wins(0))
	end)

	it("shows the message of another commit", function()
		local panel = CommitPanel:new({ git_instance = mock_git })
		panel:open("abc123")

		panel:show("def456")

		assert.are.same(
			{ "commit def456", "", "    Subject of def456" },
			vim.api.nvim_buf_get_lines(panel.bufnr, 0, -1, false)
		)

		panel:destroy()
	end)

	it("runs git only once per commit", function()
		local panel = CommitPanel:new({ git_instance = mock_git })
		panel:open("abc123")

		panel:show("def456")
		panel:show("abc123")
		panel:close()
		panel:open("def456")

		assert.stub(mock_git.get_commit_message).was.called(2)

		panel:destroy()
	end)

	it("does not run git while it is closed", function()
		local panel = CommitPanel:new({ git_instance = mock_git })

		panel:show("abc123")

		assert.stub(mock_git.get_commit_message).was.called(0)
		assert.is_false(panel:is_open())
	end)

	it("shows uncommitted changes without running git", function()
		local panel = CommitPanel:new({ git_instance = mock_git })

		panel:open("0000000000000000000000000000000000000000")

		assert.are.same({ "Not committed yet" }, vim.api.nvim_buf_get_lines(panel.bufnr, 0, -1, false))
		assert.stub(mock_git.get_commit_message).was.called(0)

		panel:destroy()
	end)

	it("shows uncommitted changes of repositories with SHA-256 hashes without running git", function()
		local panel = CommitPanel:new({ git_instance = mock_git })

		panel:open(string.rep("0", 64))

		assert.are.same({ "Not committed yet" }, vim.api.nvim_buf_get_lines(panel.bufnr, 0, -1, false))
		assert.stub(mock_git.get_commit_message).was.called(0)

		panel:destroy()
	end)

	it(
		"runs git again for a commit whose message it failed to get once another commit was shown, not on every cursor move",
		function()
			mock_git.get_commit_message = stub({}, "get_commit_message", nil)
			local panel = CommitPanel:new({ git_instance = mock_git })
			panel:open("abc123")
			assert.are.same({ "" }, vim.api.nvim_buf_get_lines(panel.bufnr, 0, -1, false))

			panel:show("abc123")
			panel:show("abc123")
			assert.stub(mock_git.get_commit_message).was.called(1)

			panel:show("def456")
			panel:show("abc123")

			assert.stub(mock_git.get_commit_message).was.called(3)

			panel:destroy()
		end
	)
end)
