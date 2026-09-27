-- Exercise the editor's mode switch against image.nvim's real edit watcher.
vim.opt.shadafile = "NONE"
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/image.nvim")
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/configs/nvim")

local document = require("image/utils/document")
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(buf, "/tmp/dotfiles-image-test.md")
vim.bo.filetype = "markdown"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "text", "![image](test.png)", "text" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })

local preview = true
package.loaded["markview.state"] = {
  get_buffer_state = function() return { enable = preview } end,
}

local images = {}
local renders = {}
local image = {
  is_enabled = function() return true end,
  get_images = function(filters)
    local result = {}
    for _, placed in pairs(images) do
      if not filters or (placed.window == filters.window and placed.buffer == filters.buffer
        and placed.namespace == filters.namespace) then
        result[#result + 1] = placed
      end
    end
    return result
  end,
  from_file = function(_, options)
    local placed = {
      id = options.id,
      window = options.window,
      buffer = options.buffer,
      namespace = options.namespace,
      render = function(_, geometry)
        renders[#renders + 1] = geometry and "inline" or "popup"
      end,
      clear = function(self) images[self.id] = nil end,
    }
    images[placed.id] = placed
    return placed
  end,
}
local integration = document.create_document_integration({
  name = "markdown",
  default_options = { filetypes = { "markdown" } },
  query_buffer_images = function()
    return { { range = { start_row = 1, start_col = 0, end_row = 1, end_col = 18 }, url = "test.png" } }
  end,
})
image.setup = function(options)
  integration.setup(image, options.integrations.markdown, {
    enabled = true,
    options = { max_height_window_percentage = 50 },
  })
end
package.loaded.image = image

local markdown_images = require("markdown_images")
markdown_images.sync(buf)
assert(vim.wait(100, function() return vim.tbl_contains(renders, "inline") end), "preview did not render")

preview = false
markdown_images.sync(buf)
vim.wait(50, function() return false end)
renders = {}
vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "changed" })
vim.wait(100, function() return false end)
assert(not vim.tbl_contains(renders, "inline"), "inline image reappeared after edit in cursor mode")
assert(next(images) == nil, "image remains placed away from cursor")

-- Undo and redo block autocmds while they change the text.
for _, command in ipairs({ "undo", "redo" }) do
  vim.cmd("silent " .. command)
  vim.wait(100, function() return false end)
  assert(not vim.tbl_contains(renders, "inline"), "inline image reappeared after " .. command .. " in cursor mode")
  assert(next(images) == nil, "image remains placed away from cursor after " .. command)
end

preview = true
markdown_images.sync(buf)
renders = {}
vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "changed again" })
assert(vim.wait(100, function() return vim.tbl_contains(renders, "inline") end),
  "inline image did not return in preview mode")

print("markdown image mode test passed")
