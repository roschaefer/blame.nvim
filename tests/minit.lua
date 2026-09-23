#!/usr/bin/env -S nvim -l

local root = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

vim.env.LAZY_STDPATH = root .. "/.tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

-- Setup lazy.nvim
require("lazy.minit").setup({
	spec = {
		{
			dir = root,
			name = "blame.nvim",
			opts = {},
		},
	},
})
