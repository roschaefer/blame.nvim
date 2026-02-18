-- tests/lua/init_spec.lua

local assert = require("luassert")
local blame = require("blame")

describe("blame.init", function()
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
			},
		}

		blame.setup(custom_opts)

		assert.are.equal("L", blame.options.keys.navigate_forward)
		assert.are.equal("H", blame.options.keys.navigate_backward)
	end)
end)
