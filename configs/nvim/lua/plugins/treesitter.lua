-- ~/.config/nvim/lua/plugins/treesitter.lua

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",

    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSUpdate", "TSUpdateSync" },

    opts = {
      ensure_installed = {
        -- Neovim / config
        "lua",
        "vim",
        "vimdoc",
        "query",

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
        "jsonc",
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
      },

      sync_install = false,
      auto_install = true,

      highlight = {
        enable = true,
      },

      indent = {
        enable = true,
      },
    },

    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
