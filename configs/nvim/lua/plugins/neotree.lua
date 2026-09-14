-- ~/.config/nvim/lua/plugins/neotree.lua

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",

    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },

    keys = {
      {
        "<C-b>",
        "<cmd>Neotree toggle filesystem reveal left<cr>",
        desc = "Toggle file explorer",
      },
    },

    opts = {
      close_if_last_window = true,

      filesystem = {
        follow_current_file = {
          enabled = true,
        },

        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },

      window = {
        position = "left",
        width = 32,

        mappings = {
          ["<C-b>"] = "close_window",
          ["q"] = "close_window",
        },
      },
    },
  },
}
