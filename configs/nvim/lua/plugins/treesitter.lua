-- ~/.config/nvim/lua/plugins/treesitter.lua

local parsers = {
  -- Neovim / config
  "lua",
  "vim",
  "vimdoc",
  "query",
  "nix",

  -- Systems languages
  "rust",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "c",
  "cpp",

  -- Python
  "python",

  -- JavaScript / TypeScript
  "javascript",
  "typescript",
  "tsx",
  "jsdoc",

  -- Web
  "html",
  "css",
  "scss",
  "json",
  "yaml",
  "toml",
  "xml",

  -- Markdown
  "markdown",
  "markdown_inline",

  -- Shell / env / config files
  "bash",
  "fish",
  "dockerfile",
  "gitignore",
  "git_config",
  "gitcommit",
  "diff",

  -- Build / misc
  "make",
  "cmake",
  "regex",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    -- During bootstrap an installed legacy checkout must be restored before
    -- its config runs. The next ordinary start goes back to eager loading.
    lazy = vim.g.dotfiles_bootstrap == true,
    build = ":TSUpdate",

    -- This is deliberately kept as data on the spec. The fresh-machine
    -- bootstrap reads the same list, so the editor and bootstrap cannot drift.
    opts = {
      ensure_installed = parsers,
    },

    config = function(_, opts)
      -- Lazy's install pipeline may load a plugin after restoring it. Parser
      -- installation belongs to the isolated driver later in the phase.
      if vim.g.dotfiles_bootstrap == true then
        return
      end

      local treesitter = require("nvim-treesitter")
      local ensure_installed = opts.ensure_installed

      -- A branch migration cannot replace Lua already loaded into this Nvim
      -- process. Keep startup usable until bootstrap restores main; this is
      -- the legacy API and can be removed once no supported machine carries
      -- the old checkout.
      if type(treesitter.install) ~= "function" then
        require("nvim-treesitter.configs").setup({
          ensure_installed = ensure_installed,
          auto_install = true,
          highlight = { enable = true },
          indent = { enable = true },
        })
        return
      end

      -- main is a different plugin from the legacy master branch: Neovim owns
      -- highlighting, while nvim-treesitter supplies queries, installation and
      -- its experimental indent expression.
      treesitter.setup()
      treesitter.install(ensure_installed)

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(event)
          if pcall(vim.treesitter.start, event.buf) then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
