local function node_text(node)
  return vim.treesitter.get_node_text(node, 0)
end

local function reference_destination(label)
  local root = vim.treesitter.get_parser(0, "markdown"):parse()[1]:root()
  label = label:match("^%[(.*)%]$") or label

  local function search(node)
    if node:type() == "link_reference_definition" then
      local definition_label = node_text(node:named_child(0)):match("^%[(.*)%]$")
      if definition_label and definition_label:lower() == label:lower() then
        return node_text(node:named_child(1))
      end
    end
    for i = 0, node:named_child_count() - 1 do
      local destination = search(node:named_child(i))
      if destination then
        return destination
      end
    end
  end

  return search(root)
end

local function link_destination()
  local root = vim.treesitter.get_parser(0, "markdown_inline"):parse()[1]:root()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = root:named_descendant_for_range(cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2])
  while node and node:type() ~= "inline" do
    local kind = node:type()
    if kind == "uri_autolink" then
      return node_text(node):match("^<(.*)>$")
    end
    if kind == "image" or kind == "inline_link" or kind == "full_reference_link" or kind == "shortcut_link" then
      local label
      for i = 0, node:named_child_count() - 1 do
        local child = node:named_child(i)
        if child:type() == "link_destination" then
          return node_text(child)
        elseif child:type() == "link_label" then
          label = node_text(child)
        end
      end
      return reference_destination(label or node_text(node))
    end
    node = node:parent()
  end
end

local function open_link()
  -- Neovim's default gx sees the link label, not its Markdown destination.
  local destination = link_destination() or vim.fn.expand("<cfile>")
  if destination == "" then
    vim.notify("No link or path under cursor", vim.log.levels.WARN)
    return
  end
  destination = destination:match("^<(.*)>$") or destination

  if vim.startswith(destination, "#") or vim.startswith(destination, "man://") then
    require("follow-md-links").follow_link()
    return
  end

  if not destination:match("^%a[%w+.-]*:") then
    destination = destination:match("^([^#]+)") or destination
    if vim.startswith(destination, "~/") then
      destination = vim.fn.expand("~") .. destination:sub(2)
    elseif not vim.startswith(destination, "/") then
      destination = vim.fs.joinpath(vim.fs.dirname(vim.api.nvim_buf_get_name(0)), destination)
    end
  end

  local _, err = vim.ui.open(destination)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

return {
  "jghauser/follow-md-links.nvim",
  ft = "markdown",

  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(event)
        local function follow_link()
          require("follow-md-links").follow_link()
        end

        vim.keymap.set("n", "<CR>", follow_link, {
          buffer = event.buf,
          desc = "Follow Markdown link",
        })
        vim.keymap.set("n", "gx", open_link, {
          buffer = event.buf,
          desc = "Open Markdown link with system app",
        })
      end,
    })
  end,
}
