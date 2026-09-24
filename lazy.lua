return {
	{
		"roschaefer/blame.nvim",
		opts = {
			keys = {
				navigate_forward = { "<CR>", "<C-]>" },
				navigate_backward = { "<C-o>", "<C-t>", "<BS>" },
				close = { "q", "<C-c>" },
			},
		},
		cmd = {
			"Blame",
		},
	},
}
