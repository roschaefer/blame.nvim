-- tests/blame/age_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local age = require("blame.age")

describe("blame.age", function()
	local day = 24 * 60 * 60

	describe("bucket", function()
		it("puts the newest commit into the last bucket and the oldest into the first", function()
			assert.are.equal(10, age.bucket(day, day, 1000 * day))
			assert.are.equal(1, age.bucket(1000 * day, day, 1000 * day))
		end)

		it("uses a logarithmic scale, so recent commits are not squashed together", function()
			-- 50 days is a bit past halfway between one day and 10000 days on a logarithmic scale
			assert.are.equal(6, age.bucket(50 * day, day, 10000 * day))
			assert.are.equal(8, age.bucket(10 * day, day, 10000 * day))
		end)

		it("puts all commits into the last bucket if they have the same age", function()
			assert.are.equal(10, age.bucket(day, day, day))
		end)

		it("handles uncommitted lines, which have no age", function()
			assert.are.equal(10, age.bucket(0, 0, 1000 * day))
			assert.are.equal(1, age.bucket(1000 * day, 0, 1000 * day))
		end)
	end)

	describe("blend", function()
		it("mixes two RGB colours", function()
			assert.are.equal(0x000000, age.blend(0x000000, 0xff8000, 0))
			assert.are.equal(0xff8000, age.blend(0x000000, 0xff8000, 1))
			assert.are.equal(0x804000, age.blend(0x000000, 0xff8000, 0.5))
			assert.are.equal(0xff8080, age.blend(0xffffff, 0xff0000, 0.5))
		end)
	end)

	describe("legend", function()
		it("shows the colours from older to newer, like GitHub's blame view", function()
			assert.are.equal(
				"Older %$GitBlameAge1$▎%$GitBlameAge2$▎%$GitBlameAge3$▎%$GitBlameAge4$▎%$GitBlameAge5$▎"
					.. "%$GitBlameAge6$▎%$GitBlameAge7$▎%$GitBlameAge8$▎%$GitBlameAge9$▎%$GitBlameAge10$▎%* Newer ",
				age.legend()
			)
		end)
	end)

	describe("winbar_legend", function()
		local snapshot
		before_each(function()
			snapshot = assert:snapshot()
		end)
		after_each(function()
			snapshot:revert()
		end)

		it("evaluates the legend whenever the winbar is drawn, with the width of the title", function()
			assert.are.equal("%{%v:lua.require'blame.age'.legend_if_fits(13)%}", age.winbar_legend(13))
		end)

		it("shows no legend before Neovim 0.12, which cannot keep the background of the winbar", function()
			stub(vim.fn, "has").returns(0)

			assert.are.equal("", age.winbar_legend(13))
		end)
	end)

	describe("define_highlights", function()
		local termguicolors, background, sign_column
		before_each(function()
			termguicolors = vim.o.termguicolors
			background = vim.api.nvim_get_hl(0, { name = "Normal" })
			sign_column = vim.api.nvim_get_hl(0, { name = "SignColumn" })
			vim.api.nvim_set_hl(0, "GitBlameAge", { fg = 0xff0000 })
			vim.api.nvim_set_hl(0, "Normal", { bg = 0x000000 })
			vim.api.nvim_set_hl(0, "SignColumn", {})
		end)
		after_each(function()
			vim.o.termguicolors = termguicolors
			vim.api.nvim_set_hl(0, "Normal", background)
			vim.api.nvim_set_hl(0, "SignColumn", sign_column)
			vim.api.nvim_set_hl(0, "GitBlameAge", {})
		end)

		it("blends the buckets from the background of the window towards the colour of GitBlameAge", function()
			vim.o.termguicolors = true

			age.define_highlights()

			assert.are.equal(0x400000, vim.api.nvim_get_hl(0, { name = "GitBlameAge1" }).fg)
			assert.are.equal(0xff0000, vim.api.nvim_get_hl(0, { name = "GitBlameAge10" }).fg)
		end)

		it("blends against the background of the sign column, where the stripe is drawn, if it has its own", function()
			vim.o.termguicolors = true
			vim.api.nvim_set_hl(0, "SignColumn", { bg = 0x202020 })

			age.define_highlights()

			assert.are.equal(0x581818, vim.api.nvim_get_hl(0, { name = "GitBlameAge1" }).fg)
			assert.are.equal(0xff0000, vim.api.nvim_get_hl(0, { name = "GitBlameAge10" }).fg)
		end)

		it("links all buckets to GitBlameAge without RGB colours", function()
			vim.o.termguicolors = false

			age.define_highlights()

			assert.are.same({ link = "GitBlameAge" }, vim.api.nvim_get_hl(0, { name = "GitBlameAge1" }))
			assert.are.same({ link = "GitBlameAge" }, vim.api.nvim_get_hl(0, { name = "GitBlameAge10" }))
		end)
	end)
end)
