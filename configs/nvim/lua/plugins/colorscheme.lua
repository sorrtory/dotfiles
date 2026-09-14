-- ~/.config/nvim/lua/plugins/colorscheme.lua

return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("onedark").setup({
        style = "darker",
      })

      require("onedark").load()
    end,
  },
}
