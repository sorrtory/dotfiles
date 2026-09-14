-- ~/.config/nvim/lua/plugins/telescope.lua

return {
  {
    "nvim-telescope/telescope.nvim",
    version = "*",

    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    keys = {
      -- VS Code-ish
      { "<C-p>", "<cmd>Telescope find_files<cr>", desc = "Quick open files" },
      { "<C-f>", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search in current file" },

      -- Leader mappings
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Search in project" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fc", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
    },

    opts = {
      defaults = {
        layout_strategy = "flex",

        layout_config = {
          width = 0.92,
          height = 0.88,

          horizontal = {
            preview_width = 0.55,
            preview_cutoff = 100,
          },

          vertical = {
            preview_height = 0.45,
            preview_cutoff = 1,
          },

          flex = {
            flip_columns = 120,
          },
        },
      },
    },
  },
}
