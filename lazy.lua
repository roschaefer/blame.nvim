return {
	{
		"roschaefer/blame.nvim",
		opts = {
			keys = {
				navigate_forward = { "<CR>", "<C-]>" },
				navigate_backward = { "<C-o>", "<C-t>", "<BS>" },
				close = { "q", "<C-c>" },
				toggle_commit_message = "K",
			},
		},
		cmd = {
			"Blame",
		},
	},
}
