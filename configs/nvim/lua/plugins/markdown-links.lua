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
        vim.keymap.set("n", "gx", follow_link, {
          buffer = event.buf,
          desc = "Follow Markdown link",
        })
      end,
    })
  end,
}
