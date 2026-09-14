-- ~/.config/nvim/lua/plugins/format.lua

return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },

		keys = {
			{
				"<leader>lf",
				function()
					require("conform").format({
						async = true,
						lsp_format = "fallback",
					})
				end,
				desc = "Format file",
			},
		},

		opts = {
			notify_on_error = true,

			format_on_save = {
				timeout_ms = 1000,
				lsp_format = "fallback",
			},

			formatters_by_ft = {
				-- Lua
				lua = { "stylua" },

				-- Web / JS / TS
				javascript = { "prettierd", "prettier", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", stop_after_first = true },

				html = { "prettierd", "prettier", stop_after_first = true },
				css = { "prettierd", "prettier", stop_after_first = true },
				scss = { "prettierd", "prettier", stop_after_first = true },
				json = { "prettierd", "prettier", stop_after_first = true },
				jsonc = { "prettierd", "prettier", stop_after_first = true },
				yaml = { "prettierd", "prettier", stop_after_first = true },
				markdown = { "prettierd", "prettier", stop_after_first = true },
				markdown_inline = { "prettierd", "prettier", stop_after_first = true },

				-- Python
				python = { "ruff_format", "ruff_organize_imports" },

				-- Go
				go = { "goimports", "gofumpt" },

				-- Shell
				sh = { "shfmt" },
				bash = { "shfmt" },

				-- C / C++
				c = { "clang_format" },
				cpp = { "clang_format" },

				-- Rust: use rustfmt if available, otherwise rust-analyzer LSP fallback
				rust = { "rustfmt", lsp_format = "fallback" },
			},
		},
	},

	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = {
			"mason-org/mason.nvim",
		},

		opts = {
			ensure_installed = {
				-- Lua
				"stylua",

				-- Web / JS / TS
				"prettierd",
				"prettier",
				"htmlhint",

				-- Python
				"ruff",

				-- Go
				"goimports",
				"gofumpt",

				-- Shell
				"shfmt",

				-- C / C++
				"clang-format",
			},
		},
	},
}
