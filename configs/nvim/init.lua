vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- New message UI (experimental in 0.12): no "Press ENTER" prompts, which the
-- first-run plugin installs otherwise trigger dozens of times.
require("vim._core.ui2").enable({})

-- Editor basics
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true

-- Keymaps
vim.keymap.set("n", "<M-z>", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle line wrap" })

vim.keymap.set("n", "<C-S-Up>", ":move .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<C-S-Down>", ":move .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("i", "<C-S-Up>", "<Esc>:move .-2<CR>==gi", { desc = "Move line up" })
vim.keymap.set("i", "<C-S-Down>", "<Esc>:move .+1<CR>==gi", { desc = "Move line down" })
vim.keymap.set("v", "<C-S-Up>", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<C-S-Down>", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })

-- Better splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true

-- Scrolling
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- Editing
vim.opt.undofile = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400

-- Spaces > tabs by default
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.shiftround = true
vim.opt.smartindent = true

-- Show invisible characters, but subtly
vim.opt.list = true
vim.opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}

-- Better completion menu behavior
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- Filetype mapping for .env files
vim.filetype.add({
  pattern = {
    [".*%.env.*"] = "sh",
  },
  filename = {
    [".env"] = "sh",
  },
})

-- Per-language indentation
local function set_indent(filetypes, width, expandtab)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = filetypes,
    callback = function()
      vim.bo.expandtab = expandtab
      vim.bo.tabstop = width
      vim.bo.shiftwidth = width
      vim.bo.softtabstop = expandtab and width or 0
    end,
  })
end

-- Web/config: 2 spaces
set_indent({
  "javascript",
  "typescript",
  "javascriptreact",
  "typescriptreact",
  "html",
  "css",
  "scss",
  "json",
  "jsonc",
  "yaml",
  "toml",
  "lua",
}, 2, true)

-- Python/Rust/C/C++: 4 spaces
set_indent({
  "python",
  "rust",
  "c",
  "cpp",
}, 4, true)

-- Go: tabs, because gofmt expects tabs
set_indent({
  "go",
}, 4, false)

-- Remember cursor position when reopening files
-- Inspired by https://github.com/farmergreg/vim-lastplace
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore cursor position",
  callback = function(event)
    local buf = event.buf
    local filetype = vim.bo[buf].filetype
    local buftype = vim.bo[buf].buftype

    if buftype ~= "" then
      return
    end

    if vim.tbl_contains({ "gitcommit", "gitrebase", "svn", "hgcommit" }, filetype) then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local line = mark[1]
    local col = mark[2]
    local line_count = vim.api.nvim_buf_line_count(buf)

    if line < 1 or line > line_count then
      return
    end

    pcall(vim.api.nvim_win_set_cursor, 0, { line, col })

    -- Open folds at cursor, then center the line.
    vim.cmd("normal! zvzz")
  end,
})

-- https://lazy.folke.io/installation
require("config.lazy")

-- The theme chosen in home.nix decides which colorscheme is loaded: the one
-- its plugin provides, or "dotfiles", drawn from the palette in
-- colors/dotfiles.lua. Overrides from home.nix land on top of whichever it is.
local theme = require("theme")
pcall(vim.cmd.colorscheme, theme.colorscheme or "dotfiles")
theme.apply_overrides()
