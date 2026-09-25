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
		assert.are.equal("Show git blame information and file content side by side.", commands["Blame"].definition)
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

	it("has default close keys of q and <C-c>", function()
		blame.setup({})
		assert.are.same({ "q", "<C-c>" }, blame.options.keys.close)
	end)

	it("has default navigation keys like the tag stack and the jumplist", function()
		blame.setup({})
		assert.are.same({ "<CR>", "<C-]>" }, blame.options.keys.navigate_forward)
		assert.are.same({ "<C-o>", "<C-t>", "<BS>" }, blame.options.keys.navigate_backward)
	end)

	it("maps all keys in both the blame and the file content buffer", function()
		blame.setup({})
		vim.cmd("edit README.md")
		local original_tabpage = vim.api.nvim_get_current_tabpage()

		blame.show_blame_info()

		local wins = vim.api.nvim_tabpage_list_wins(0)
		assert.are.equal(2, #wins)
		for _, win in ipairs(wins) do
			local mapped_keys = vim.tbl_map(function(keymap)
				return keymap.lhs
			end, vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(win), "n"))
			table.sort(mapped_keys)
			assert.are.same({ "<BS>", "<C-C>", "<C-O>", "<C-T>", "<C-]>", "<CR>", "K", "q" }, mapped_keys)
		end
		vim.api.nvim_feedkeys("K", "x", false)
		local panel_winid = vim.api.nvim_tabpage_list_wins(0)[3]
		local panel_keys = vim.tbl_map(function(keymap)
			return keymap.lhs
		end, vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(panel_winid), "n"))
		table.sort(panel_keys)
		assert.are.same({ "<C-C>", "K", "q" }, panel_keys)

		vim.api.nvim_feedkeys("q", "x", false)
		assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())
		vim.cmd("bwipeout README.md")
	end)

	it("closes the commit panel with its toggle key from inside and returns to the previous window", function()
		blame.setup({})
		vim.cmd("edit README.md")
		local original_tabpage = vim.api.nvim_get_current_tabpage()
		blame.show_blame_info()
		local blame_winid = vim.api.nvim_get_current_win()

		vim.api.nvim_feedkeys("K", "x", false)
		vim.api.nvim_feedkeys(vim.keycode("<C-w>j"), "x", false)
		assert.are.equal("git", vim.bo.filetype)
		vim.api.nvim_feedkeys("K", "x", false)

		assert.are.equal(2, #vim.api.nvim_tabpage_list_wins(0))
		assert.are.equal(blame_winid, vim.api.nvim_get_current_win())

		vim.api.nvim_feedkeys("q", "x", false)
		assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())
		vim.cmd("bwipeout README.md")
	end)

	it("closes the whole view with the close key from inside the commit panel", function()
		blame.setup({})
		vim.cmd("edit README.md")
		local original_tabpage = vim.api.nvim_get_current_tabpage()
		blame.show_blame_info()
		vim.api.nvim_feedkeys("K", "x", false)
		vim.api.nvim_feedkeys(vim.keycode("<C-w>j"), "x", false)

		vim.api.nvim_feedkeys("q", "x", false)

		assert.are.same({ original_tabpage }, vim.api.nvim_list_tabpages())
		vim.cmd("bwipeout README.md")
	end)

	it("keeps keymaps of the user config for the blame filetype", function()
		local augroup = vim.api.nvim_create_augroup("init_spec_user_config", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			group = augroup,
			pattern = "blame",
			command = "nnoremap <buffer> q <Cmd>let g:init_spec_user_q = 1<CR>",
		})
		blame.setup({})
		vim.cmd("edit README.md")
		local original_tabpage = vim.api.nvim_get_current_tabpage()

		blame.show_blame_info()

		assert.are.equal("<Cmd>let g:init_spec_user_q = 1<CR>", vim.fn.maparg("q", "n"))

		vim.api.nvim_feedkeys(vim.keycode("<C-c>"), "x", false)
		assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())
		vim.api.nvim_del_augroup_by_id(augroup)
		vim.cmd("bwipeout README.md")
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
