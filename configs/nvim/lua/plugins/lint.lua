-- ~/.config/nvim/lua/plugins/lint.lua

return {
	{
		"mfussenegger/nvim-lint",
		event = { "BufReadPost", "BufNewFile", "BufWritePost" },

		keys = {
			{
				"<leader>ll",
				function()
					require("lint").try_lint()
				end,
				desc = "Lint current file",
			},
		},

		config = function()
			local lint = require("lint")

			lint.linters_by_ft = {
				html = { "htmlhint" },
			}

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				callback = function()
					lint.try_lint()
				end,
			})
		end,
	},
}
