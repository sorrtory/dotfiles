-- A colorscheme drawn from the palette, for a theme that declares no plugin
-- of its own (autumn-leaves). The roles come from modules/theme; this file is
-- the mapping from them to Neovim's highlight groups, and is the place to
-- adjust how a generated theme looks.

local M = {}

function M.apply(colors)
  local c = colors
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  vim.o.background = "dark"
  vim.g.colors_name = "dotfiles"

  local groups = {
    Normal = { fg = c.text, bg = c.base },
    NormalNC = { fg = c.text, bg = c.base },
    NormalFloat = { fg = c.text, bg = c.mantle },
    FloatBorder = { fg = c.overlay, bg = c.mantle },
    FloatTitle = { fg = c.accent, bg = c.mantle, bold = true },
    Cursor = { fg = c.base, bg = c.text },
    CursorLine = { bg = c.surface },
    CursorLineNr = { fg = c.accent, bold = true },
    LineNr = { fg = c.muted },
    SignColumn = { bg = c.base },
    ColorColumn = { bg = c.surface },
    Visual = { bg = c.overlay },
    VisualNOS = { bg = c.overlay },
    Search = { fg = c.base, bg = c.warning },
    IncSearch = { fg = c.base, bg = c.accent },
    CurSearch = { fg = c.base, bg = c.accent },
    MatchParen = { fg = c.accent, bold = true },
    Whitespace = { fg = c.overlay },
    NonText = { fg = c.overlay },
    EndOfBuffer = { fg = c.base },
    Folded = { fg = c.subtext, bg = c.surface },
    FoldColumn = { fg = c.muted, bg = c.base },
    Conceal = { fg = c.muted },
    Directory = { fg = c.accent2 },
    Title = { fg = c.accent, bold = true },
    ErrorMsg = { fg = c.error },
    WarningMsg = { fg = c.warning },
    MoreMsg = { fg = c.success },
    Question = { fg = c.info },
    ModeMsg = { fg = c.subtext, bold = true },
    MsgArea = { fg = c.subtext },

    -- Splits, menus and the status line
    WinSeparator = { fg = c.overlay },
    StatusLine = { fg = c.subtext, bg = c.surface },
    StatusLineNC = { fg = c.muted, bg = c.mantle },
    TabLine = { fg = c.muted, bg = c.mantle },
    TabLineSel = { fg = c.text, bg = c.base },
    TabLineFill = { bg = c.mantle },
    Pmenu = { fg = c.text, bg = c.mantle },
    PmenuSel = { fg = c.base, bg = c.accent },
    PmenuSbar = { bg = c.surface },
    PmenuThumb = { bg = c.overlay },
    WildMenu = { fg = c.base, bg = c.accent },
    QuickFixLine = { bg = c.surface },

    -- Syntax
    Comment = { fg = c.muted, italic = true },
    Constant = { fg = c.accent2 },
    String = { fg = c.success },
    Character = { fg = c.success },
    Number = { fg = c.accent2 },
    Boolean = { fg = c.accent2 },
    Float = { fg = c.accent2 },
    Identifier = { fg = c.text },
    Function = { fg = c.warning },
    Statement = { fg = c.error },
    Conditional = { fg = c.error },
    Repeat = { fg = c.error },
    Label = { fg = c.error },
    Operator = { fg = c.accent },
    Keyword = { fg = c.error },
    Exception = { fg = c.error },
    PreProc = { fg = c.info },
    Include = { fg = c.error },
    Define = { fg = c.info },
    Macro = { fg = c.info },
    Type = { fg = c.warning },
    StorageClass = { fg = c.warning },
    Structure = { fg = c.warning },
    Typedef = { fg = c.warning },
    Special = { fg = c.accent },
    SpecialKey = { fg = c.overlay },
    Delimiter = { fg = c.subtext },
    Underlined = { fg = c.accent2, underline = true },
    Error = { fg = c.error },
    Todo = { fg = c.base, bg = c.warning, bold = true },

    -- Diffs and version control
    DiffAdd = { fg = c.success, bg = c.surface },
    DiffChange = { fg = c.warning, bg = c.surface },
    DiffDelete = { fg = c.error, bg = c.surface },
    DiffText = { fg = c.base, bg = c.warning },
    Added = { fg = c.success },
    Changed = { fg = c.warning },
    Removed = { fg = c.error },

    -- Diagnostics
    DiagnosticError = { fg = c.error },
    DiagnosticWarn = { fg = c.warning },
    DiagnosticInfo = { fg = c.info },
    DiagnosticHint = { fg = c.accent2 },
    DiagnosticOk = { fg = c.success },
    DiagnosticUnderlineError = { sp = c.error, undercurl = true },
    DiagnosticUnderlineWarn = { sp = c.warning, undercurl = true },
    DiagnosticUnderlineInfo = { sp = c.info, undercurl = true },
    DiagnosticUnderlineHint = { sp = c.accent2, undercurl = true },

    -- Treesitter, where it does not fall back to the groups above
    ["@variable"] = { fg = c.text },
    ["@variable.builtin"] = { fg = c.error },
    ["@variable.parameter"] = { fg = c.subtext },
    ["@property"] = { fg = c.accent2 },
    ["@field"] = { fg = c.accent2 },
    ["@constructor"] = { fg = c.warning },
    ["@punctuation.bracket"] = { fg = c.subtext },
    ["@punctuation.delimiter"] = { fg = c.subtext },
    ["@tag"] = { fg = c.error },
    ["@tag.attribute"] = { fg = c.warning },
    ["@markup.heading"] = { fg = c.accent, bold = true },
    ["@markup.link"] = { fg = c.accent2, underline = true },
    ["@markup.raw"] = { fg = c.success },

    -- The plugins this configuration carries
    NeoTreeNormal = { fg = c.subtext, bg = c.mantle },
    NeoTreeNormalNC = { fg = c.subtext, bg = c.mantle },
    NeoTreeDirectoryName = { fg = c.accent2 },
    NeoTreeDirectoryIcon = { fg = c.accent2 },
    NeoTreeGitModified = { fg = c.warning },
    NeoTreeGitAdded = { fg = c.success },
    NeoTreeGitDeleted = { fg = c.error },
    TelescopeNormal = { fg = c.text, bg = c.mantle },
    TelescopeBorder = { fg = c.overlay, bg = c.mantle },
    TelescopeTitle = { fg = c.accent, bold = true },
    TelescopeSelection = { bg = c.surface },
    TelescopeMatching = { fg = c.accent },
    GitSignsAdd = { fg = c.success },
    GitSignsChange = { fg = c.warning },
    GitSignsDelete = { fg = c.error },
  }

  for group, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, group, spec)
  end

  -- The 16 colors a :terminal buffer uses, from the same palette.
  local ansi = {
    c.black, c.red, c.green, c.yellow, c.blue, c.magenta, c.cyan, c.white,
    c.brightBlack, c.brightRed, c.brightGreen, c.brightYellow,
    c.brightBlue, c.brightMagenta, c.brightCyan, c.brightWhite,
  }
  for index, color in ipairs(ansi) do
    vim.g["terminal_color_" .. (index - 1)] = color
  end
end

return M
