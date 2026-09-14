-- ~/.config/nvim/lua/plugins/lsp.lua

local servers = {
	-- Neovim / Lua
	"lua_ls",

	-- Systems
	"rust_analyzer",
	"gopls",
	"clangd",

	-- Python
	"pyright",

	-- JS / TS / Web
	"ts_ls",
	"eslint",
	"html",
	"cssls",
	"jsonls",
	"tailwindcss",

	-- Config / shell
	"taplo", -- TOML
	"yamlls",
	"bashls",

	-- Markdown / Docker
	"marksman",
	"dockerls",
}

return {
	{
		"mason-org/mason.nvim",
		opts = {
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		},
	},

	{
		"mason-org/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },

		dependencies = {
			"mason-org/mason.nvim",
			"neovim/nvim-lspconfig",
			"saghen/blink.cmp",
		},

		opts = {
			ensure_installed = servers,
			automatic_enable = true,
		},

		config = function(_, opts)
			-- Completion capabilities from blink.cmp.
			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(),
			})

			-- Diagnostics
			vim.diagnostic.config({
				virtual_text = {
					spacing = 2,
					prefix = "●",
				},
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
				},
				jump = {
					on_jump = function(diagnostic, bufnr)
						if diagnostic then
							vim.diagnostic.open_float({
								bufnr = bufnr,
								scope = "cursor",
								focus = false,
							})
						end
					end,
				},
			})

			-- Global diagnostic keymaps
			vim.keymap.set("n", "[d", function()
				vim.diagnostic.jump({ count = -1 })
			end, { desc = "Previous diagnostic" })

			vim.keymap.set("n", "]d", function()
				vim.diagnostic.jump({ count = 1 })
			end, { desc = "Next diagnostic" })

			vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Line diagnostics" })
			vim.keymap.set("n", "<leader>lq", vim.diagnostic.setloclist, { desc = "Diagnostics list" })

			-- LSP keymaps, only active when an LSP attaches to the buffer
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(event)
					local bufnr = event.buf
					local client = vim.lsp.get_client_by_id(event.data.client_id)

					local function map(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, {
							buffer = bufnr,
							desc = desc,
						})
					end

					map("n", "K", vim.lsp.buf.hover, "Hover")
					map("n", "gd", vim.lsp.buf.definition, "Go to definition")
					map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
					map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
					map("n", "gr", vim.lsp.buf.references, "Go to references")
					map("n", "gt", vim.lsp.buf.type_definition, "Go to type definition")

					map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
					map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")

					-- Formatting lives in format.lua via conform.nvim.
					map("n", "<leader>ls", vim.lsp.buf.signature_help, "Signature help")

					if vim.lsp.inlay_hint then
						map("n", "<leader>li", function()
							local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
							vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
						end, "Toggle inlay hints")
					end

					-- TypeScript / JavaScript helpers
					if client and client.name == "ts_ls" then
						local function ts_exec(title, command, arguments)
							client:exec_cmd({
								title = title,
								command = command,
								arguments = arguments,
							}, {
								bufnr = bufnr,
							})
						end

						map("n", "<leader>lo", function()
							ts_exec("Organize Imports", "_typescript.organizeImports", {
								vim.api.nvim_buf_get_name(bufnr),
								{
									mode = "All",
								},
							})
						end, "Organize imports")

						map("n", "<leader>lR", function()
							local old_path = vim.api.nvim_buf_get_name(bufnr)
							local new_path = vim.fn.input("New path: ", old_path, "file")

							if new_path == "" or new_path == old_path then
								return
							end

							ts_exec("Rename File", "_typescript.applyRenameFile", {
								{
									sourceUri = vim.uri_from_fname(old_path),
									targetUri = vim.uri_from_fname(new_path),
								},
							})
						end, "Rename file and update imports")
					end
				end,
			})

			-- Lua
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						runtime = {
							version = "LuaJIT",
						},
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							checkThirdParty = false,
							library = {
								vim.env.VIMRUNTIME,
							},
						},
						telemetry = {
							enable = false,
						},
					},
				},
			})

			-- Go
			vim.lsp.config("gopls", {
				settings = {
					gopls = {
						gofumpt = true,
						staticcheck = true,
					},
				},
			})

			-- Rust
			vim.lsp.config("rust_analyzer", {
				settings = {
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
						},
						check = {
							command = "clippy",
						},
					},
				},
			})

			-- C / C++
			vim.lsp.config("clangd", {
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--completion-style=detailed",
				},
			})

			-- HTML
			vim.lsp.config("html", {
				init_options = {
					-- Let conform/prettier handle formatting instead of html-lsp.
					provideFormatter = false,
				},

				settings = {
					html = {
						validate = {
							scripts = true,
							styles = true,
						},

						hover = {
							documentation = true,
							references = true,
						},

						suggest = {
							html5 = true,
						},
					},
				},
			})
			-- TypeScript / JavaScript
			vim.lsp.config("ts_ls", {
				init_options = {
					hostInfo = "neovim",

					preferences = {
						includeCompletionsForModuleExports = true,
						includeCompletionsForImportStatements = true,
						includeCompletionsWithSnippetText = true,

						includeInlayParameterNameHints = "literals",
						includeInlayParameterNameHintsWhenArgumentMatchesName = false,
						includeInlayFunctionParameterTypeHints = true,
						includeInlayVariableTypeHints = false,
						includeInlayPropertyDeclarationTypeHints = true,
						includeInlayFunctionLikeReturnTypeHints = true,
						includeInlayEnumMemberValueHints = true,
					},
				},
			})

			require("mason-lspconfig").setup(opts)
		end,
	},
}
