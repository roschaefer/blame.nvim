return {
	-- nui.nvim can be lazy loaded
	{ "MunifTanjim/nui.nvim", lazy = true },
	{
		"roschaefer/blame.nvim",
		opts = {
			keys = {
				navigate_forward = "<CR>",
				navigate_backward = "<BS>",
			},
		},
		cmd = {
			"Blame",
		},
	},
}
