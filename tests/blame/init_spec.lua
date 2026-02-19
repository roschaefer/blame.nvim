-- tests/lua/init_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local blame = require("blame")

describe("blame.init", function()
	local snapshot
	before_each(function()
		snapshot = assert:snapshot()
	end)

	after_each(function()
		snapshot:revert()
	end)

	it("registers the Blame command on setup", function()
		-- Ensure command doesn't already exist or handle it if it does
		pcall(vim.api.nvim_del_user_command, "Blame")

		blame.setup()

		local commands = vim.api.nvim_get_commands({})
		assert.is_not_nil(commands["Blame"])
		assert.are.equal("Show git blame information and file content in a popup.", commands["Blame"].definition)
	end)

	it("applies user options during setup", function()
		local custom_opts = {
			keys = {
				navigate_forward = "L",
				navigate_backward = "H",
				close = { "q", "<C-c>" },
			},
		}

		blame.setup(custom_opts)

		assert.are.equal("L", blame.options.keys.navigate_forward)
		assert.are.equal("H", blame.options.keys.navigate_backward)
		assert.are.same({ "q", "<C-c>" }, blame.options.keys.close)
	end)

	it("has default close keys of <ESC>, <C-c> and q", function()
		blame.setup({})
		assert.are.same({ "<ESC>", "<C-c>", "q" }, blame.options.keys.close)
	end)

	it("shows a warning if the current file is not in a git repository", function()
		local tmpdir = vim.fn.tempname()
		vim.fn.mkdir(tmpdir, "p")
		local buf_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf_id, tmpdir .. "/anyfile")

		local old_win = vim.api.nvim_get_current_win()
		local new_win = vim.api.nvim_open_win(buf_id, true, {
			relative = "editor",
			width = 1,
			height = 1,
			row = 0,
			col = 0,
		})

		local notify_stub = stub(vim, "notify")

		blame.show_blame_info()

		assert.stub(notify_stub).was.called_with("blame.nvim: Not in a git repository.", vim.log.levels.WARN)

		vim.api.nvim_set_current_win(old_win)
		vim.api.nvim_win_close(new_win, true)
		vim.api.nvim_buf_delete(buf_id, { force = true })
		vim.fn.delete(tmpdir, "rf")
	end)
end)
