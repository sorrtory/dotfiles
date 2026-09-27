local M = {}
local current_preview
local watched_buffers = {}

local function preview_enabled(buf)
  local state = require("markview.state").get_buffer_state(buf, false)
  return not state or state.enable
end

local function options(preview)
  local integration = {
    only_render_image_at_cursor = not preview,
    only_render_image_at_cursor_mode = "popup",
  }

  return {
    backend = "sixel", -- WezTerm's Kitty graphics support is incomplete.
    processor = "magick_cli",
    integrations = {
      markdown = integration,
      -- Markdown may contain raw HTML <img> tags, which need the HTML parser.
      html = vim.tbl_extend("force", integration, {
        enabled = true,
        filetypes = { "markdown" },
      }),
      asciidoc = { enabled = false },
      typst = { enabled = false },
      neorg = { enabled = false },
      syslang = { enabled = false },
    },
    hijack_file_patterns = {}, -- Leave image files to gx and the system viewer.
  }
end

local function clear_placements(image, buf)
  -- image.nvim closes popup windows on CursorMoved. Close one before
  -- switching modes so its old window does not cover the inline image.
  for _, placed in ipairs(image.get_images()) do
    if placed.buffer and vim.api.nvim_buf_is_valid(placed.buffer)
      and vim.bo[placed.buffer].filetype == "image_nvim_popup" then
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
      break
    end
  end
  for _, placed in ipairs(image.get_images()) do
    placed:clear()
  end
end

local function watch_edits(buf)
  if watched_buffers[buf] then return end
  watched_buffers[buf] = true

  -- image.nvim's first on_lines callback keeps the options from its first
  -- setup, so after a mode switch every edit renders in the old mode. Our
  -- callback is attached after it and takes over the render it just queued:
  -- the scheduler keeps only the newest callback per key, and ours re-enters
  -- through BufEnter, which the current setup owns. The autocmd has to run
  -- from the scheduler rather than here, because undo and redo block
  -- autocmds while they change the text.
  local scheduler = require("image/utils/render_scheduler")
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      watched_buffers[buf] = nil
      return
    end
    if not vim.api.nvim_buf_attach(buf, false, {
      on_lines = function(_, changed_buf)
        for _, integration in ipairs({ "markdown", "html" }) do
          local key = ("document:%s:buffer:%d"):format(integration, changed_buf)
          scheduler.schedule(key, function()
            local group = "image.nvim:" .. integration
            local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = group, event = "BufEnter" })
            if ok and #autocmds > 0 and vim.api.nvim_buf_is_valid(changed_buf) then
              vim.api.nvim_exec_autocmds("BufEnter", { group = group, buffer = changed_buf })
            end
          end)
        end
      end,
      on_detach = function()
        watched_buffers[buf] = nil
      end,
    }) then
      watched_buffers[buf] = nil
    end
  end)
end

function M.sync(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local image = require("image")
  if not image.is_enabled() then return end

  local preview = preview_enabled(buf)
  if preview ~= current_preview then
    if current_preview ~= nil then clear_placements(image, buf) end

    image.setup(options(preview))
    current_preview = preview
  end
  watch_edits(buf)
end

function M.toggle()
  local image = require("image")
  if image.is_enabled() then
    image.disable()
    clear_placements(image, vim.api.nvim_get_current_buf())
    current_preview = nil
    vim.notify("Markdown images disabled")
  else
    image.enable()
    M.sync()
    vim.notify("Markdown images enabled")
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(event)
    if vim.bo[event.buf].filetype == "markdown" and package.loaded.image then
      M.sync(event.buf)
    end
  end,
})

return M
