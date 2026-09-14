-- ~/.config/nvim/lua/plugins/oil.lua

return {
  {
    "stevearc/oil.nvim",
    lazy = false,

    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
      { "<leader>e", "<cmd>Oil<cr>", desc = "Open file explorer" },
    },

    opts = {
      default_file_explorer = true,

      columns = {
        "icon",
      },

      view_options = {
        show_hidden = true,
      },

      keymaps = {
        ["<C-p>"] = false,
        ["q"] = "actions.close",
      },
    },
  },
}
