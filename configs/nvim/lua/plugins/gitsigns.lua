-- ~/.config/nvim/lua/plugins/gitsigns.lua

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },

    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },

      signs_staged = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },

      signcolumn = true,
      numhl = false,
      linehl = false,
      word_diff = false,

      current_line_blame = false,

      preview_config = {
        border = "rounded",
      },

      on_attach = function(bufnr)
        local gs = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            desc = desc,
          })
        end

        -- Navigation
        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
            vim.cmd("normal! zz")
          end
        end, "Next git hunk")

        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
            vim.cmd("normal! zz")
          end
        end, "Previous git hunk")

        -- Preview
        map("n", "<leader>hp", gs.preview_hunk, "Preview git hunk")

        -- Stage / reset hunk
        map("n", "<leader>hs", gs.stage_hunk, "Stage git hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset git hunk")

        map("v", "<leader>hs", function()
          gs.stage_hunk({
            vim.fn.line("."),
            vim.fn.line("v"),
          })
        end, "Stage selected git hunk")

        map("v", "<leader>hr", function()
          gs.reset_hunk({
            vim.fn.line("."),
            vim.fn.line("v"),
          })
        end, "Reset selected git hunk")

        -- Buffer actions
        map("n", "<leader>hS", gs.stage_buffer, "Stage git buffer")
        map("n", "<leader>hR", gs.reset_buffer, "Reset git buffer")
        map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")

        -- Blame / diff
        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end, "Git blame line")

        map("n", "<leader>hd", gs.diffthis, "Git diff this")

        map("n", "<leader>hD", function()
          gs.diffthis("~")
        end, "Git diff against previous commit")

        -- Toggle helpers
        map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle git blame")
        map("n", "<leader>hw", gs.toggle_word_diff, "Toggle word diff")
      end,
    },
  },
}
