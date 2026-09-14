-- ~/.config/nvim/lua/plugins/completion.lua

return {
  {
    "saghen/blink.cmp",
    version = "*",
    event = { "InsertEnter", "CmdlineEnter" },

    opts = {
      keymap = {
        preset = "enter",

        -- VS Code-like:
        -- Tab accepts completion if available,
        -- jumps through snippets if inside one,
        -- otherwise behaves like normal Tab.
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },

        ["<CR>"] = { "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
      },

      appearance = {
        nerd_font_variant = "mono",
      },

      completion = {
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },

        documentation = {
          auto_show = true,
          auto_show_delay_ms = 300,
        },
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },

      snippets = {
        preset = "default",
      },

      cmdline = {
        enabled = true,
      },
    },
  },
}
