return {
  "OXY2DEV/markview.nvim",
  lazy = false,

  config = function(_, opts)
    require("markview").setup(opts)

    local colors = require("theme").colors
    local function apply_code_colors()
      local surface = colors.surface or vim.api.nvim_get_hl(0, { name = "CursorLine" }).bg
      local muted = colors.muted or vim.api.nvim_get_hl(0, { name = "Comment" }).fg
      vim.api.nvim_set_hl(0, "DotfilesMarkdownCode", { bg = surface })
      vim.api.nvim_set_hl(0, "DotfilesMarkdownCodeInfo", { fg = muted, bg = surface })
      -- Markview draws the block's rectangle. Treesitter's code-block node
      -- also spans a list item's indent and the closing fence's line, so its
      -- own surface would leak past the rectangle's left edge.
      vim.api.nvim_set_hl(0, "@markup.raw.block.markdown", {})
    end

    vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_code_colors })
    apply_code_colors()
  end,

  keys = {
    { "<leader>mt", "<cmd>Markview toggle<cr>", desc = "Toggle Markview preview" },
    { "<leader>ms", "<cmd>Markview splitToggle<cr>", desc = "Toggle Markview split view" },
    { "<leader>mh", "<cmd>Markview hybridToggle<cr>", desc = "Toggle Markview hybrid mode" },
  },

  opts = {
    preview = {
      enable = true,
      filetypes = { "markdown" },
      -- follow-md-links.nvim handles navigation; Markview only renders.
      map_gx = false,
    },
    -- Keep the normal Markdown text visible; render only fenced code blocks.
    markdown = {
      block_quotes = { enable = false },
      code_blocks = {
        style = "block",
        min_width = 0,
        pad_amount = 1,
        sign = false,
        border_hl = "DotfilesMarkdownCode",
        info_hl = "DotfilesMarkdownCodeInfo",
        label_hl = "DotfilesMarkdownCodeInfo",
        default = {
          block_hl = "DotfilesMarkdownCode",
          pad_hl = "DotfilesMarkdownCode",
        },
        ["diff"] = {
          block_hl = "DotfilesMarkdownCode",
          pad_hl = "DotfilesMarkdownCode",
        },
      },
      headings = { enable = false },
      horizontal_rules = { enable = false },
      list_items = { enable = false },
      metadata_minus = { enable = false },
      metadata_plus = { enable = false },
      reference_definitions = { enable = false },
      tables = { enable = false },
    },
    markdown_inline = { enable = false },
  },
}
