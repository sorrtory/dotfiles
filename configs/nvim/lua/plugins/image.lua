return {
  "3rd/image.nvim",
  ft = "markdown",
  build = false, -- Use ImageMagick's CLI instead of building the Lua rock.
  keys = {
    { "<leader>mi", function() require("markdown_images").toggle() end, desc = "Toggle Markdown images" },
  },
  config = function()
    require("markdown_images").sync()
  end,
}
