-- ~/.config/nvim/lua/plugins/lualine.lua

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",

    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    opts = {
      options = {
        theme = "auto",
        globalstatus = true,

        component_separators = "",
        section_separators = "",

        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
      },

      sections = {
        lualine_a = {
          "mode",
        },

        lualine_b = {
          {
            "branch",
            icon = "",
          },
          {
            "diff",
            symbols = {
              added = "+",
              modified = "~",
              removed = "-",
            },
          },
        },

        lualine_c = {
          {
            "filename",
            path = 1,
            symbols = {
              modified = " 󰏫",
              readonly = " 󰌾 READONLY",
              unnamed = "[No Name]",
              newfile = " 󰝒",
            },
          },
        },

        lualine_x = {
          "diagnostics",
          "filetype",
        },

        lualine_y = {
          "progress",
        },

        lualine_z = {
          "location",
        },
      },

      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
          {
            "filename",
            path = 1,
            symbols = {
              modified = " 󰏫",
              readonly = " ",
              unnamed = "[No Name]",
              newfile = " 󰝒",
            },
          },
        },
        lualine_x = {
          "location",
        },
        lualine_y = {},
        lualine_z = {},
      },

      extensions = {
        "neo-tree",
        "oil",
        "quickfix",
      },
    },
  },
}
