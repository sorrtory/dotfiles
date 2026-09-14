return {
  "OXY2DEV/markview.nvim",
  lazy = false,

  keys = {
    { "<leader>mt", "<cmd>Markview toggle<cr>", desc = "Toggle Markview preview" },
    { "<leader>ms", "<cmd>Markview splitToggle<cr>", desc = "Toggle Markview split view" },
    { "<leader>mh", "<cmd>Markview hybridToggle<cr>", desc = "Toggle Markview hybrid mode" },
  },

  opts = {
    preview = {
      enable = false,
    },
  },
}
