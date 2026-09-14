-- ~/.config/nvim/lua/plugins/todo.lua

return {
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },

    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    keys = {
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
      { "<leader>tq", "<cmd>TodoQuickFix<cr>", desc = "TODO quickfix" },
    },

    opts = {},
  },
}
