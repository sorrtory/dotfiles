-- ~/.config/nvim/lua/plugins/lualine.lua

local theme = require("theme")

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

    -- lualine builds its own highlight groups from the colorscheme, which
    -- transparent.nvim's list of groups never covers, so a transparent editor
    -- still drew a black bar across the bottom. Handing those groups to the
    -- plugin clears them, and it keeps clearing them after a colorscheme
    -- reload. Only the middle sections: a and z are the mode and the
    -- position, which are meant to carry a color of their own.
    config = function(_, opts)
      require("lualine").setup(opts)
      if theme.transparency then
        local transparent = require("transparent")
        for _, section in ipairs({ "b", "c", "x", "y" }) do
          transparent.clear_prefix("lualine_" .. section)
        end
      end
    end,
  },
}
