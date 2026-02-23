return {
	-- nui.nvim can be lazy loaded
	{ "MunifTanjim/nui.nvim", lazy = true },
	{
		"roschaefer/blame.nvim",
		opts = {
			keys = {
				navigate_forward = "<CR>",
				navigate_backward = "<BS>",
				switch_focus = "<TAB>",
				close = { "<ESC>", "<C-c>", "q" },
			},
		},
		cmd = {
			"Blame",
		},
	},
}
