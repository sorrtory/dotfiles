-- A colorscheme drawn from the palette, for a theme that declares no plugin
-- of its own (autumn-leaves). The roles come from modules/theme; this file is
-- the mapping from them to Neovim's highlight groups, and is the place to
-- adjust how a generated theme looks.

local M = {}

-- `ratio` of `to` mixed into `from`, the same operation as
-- modules/theme/color.nix's `mix`. The heading ramp below asks for shades
-- between two roles that no palette names, and deriving them from the roles
-- keeps the ramp a statement about the palette rather than a second copy of
-- its hexes.
local function blend(from, to, ratio)
  local out = "#"
  for offset = 2, 6, 2 do
    local a = tonumber(from:sub(offset, offset + 1), 16)
    local b = tonumber(to:sub(offset, offset + 1), 16)
    out = out .. string.format("%02x", math.floor(a + (b - a) * ratio + 0.5))
  end
  return out
end

function M.apply(colors)
  local c = colors
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  vim.o.background = "dark"
  vim.g.colors_name = "dotfiles"

  -- Markdown heading levels as a leaf turning: maple red at the top, then
  -- copper, amber, and a green fourth level. The palette is warm by design, so
  -- the first three rungs are 9 to 12 degrees of hue apart and would read as
  -- one color; each is nudged toward the page or the text until neighbouring
  -- levels differ in brightness as well.
  --
  -- The ramp can be the theme's own metaphor rather than a hierarchy because
  -- depth is already legible without it: Markview renders no preview, so the
  -- "#" of each heading are on screen and counting them is how a level is
  -- read. It stops at four because this repository's Markdown holds 704
  -- headings and ten of them are H4; a fifth and sixth rung would be spent on
  -- levels nothing writes. Gold stays out of it: inline code has that role,
  -- and inline code outnumbers headings five to one.
  local heading = {
    blend(c.error, c.base, 0.14),
    blend(c.accent, c.text, 0.10),
    blend(c.accent2, c.base, 0.06),
    blend(c.info, c.text, 0.06),
  }

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

    -- Markdown, where the structure carries the color and the prose does not:
    -- a page is mostly sentences, and a sentence is the text color at every
    -- depth. Marking the structure is also all a warm palette has room for,
    -- since every hue it holds sits between 8 and 95 degrees.
    ["@markup.heading"] = { fg = heading[1], bold = true },
    ["@markup.heading.1"] = { fg = heading[1], bold = true },
    ["@markup.heading.2"] = { fg = heading[2], bold = true },
    ["@markup.heading.3"] = { fg = heading[3], bold = true },
    ["@markup.heading.4"] = { fg = heading[4], bold = true },
    ["@markup.heading.5"] = { fg = c.muted, bold = true },
    ["@markup.heading.6"] = { fg = c.muted, bold = true },
    -- A link points out of the document, which is the one thing worth
    -- separating from a heading, and every hue is already a heading or inline
    -- code. So it separates by texture: the label is the only underlined text
    -- on the page, and the URL beside it is noise.
    ["@markup.link"] = { fg = c.muted },
    ["@markup.link.label"] = { fg = c.text, underline = true },
    ["@markup.link.url"] = { fg = c.muted, underline = true },
    ["@markup.raw"] = { fg = c.success },
    -- A fenced block is marked by its surface rather than by a color of its
    -- own, because the injected language already highlights the code in it.
    ["@markup.raw.block"] = { bg = c.surface },
    ["@markup.quote"] = { fg = c.muted, italic = true },
    ["@markup.strikethrough"] = { fg = c.muted, strikethrough = true },
    ["@markup.list"] = { fg = c.subtext },
    ["@markup.list.checked"] = { fg = c.info },
    ["@markup.list.unchecked"] = { fg = c.muted },
    -- The ">" of a quote and the "---" of a break, kept quiet. Scoped to
    -- Markdown so that a format specifier in a string keeps Special.
    ["@punctuation.special.markdown"] = { fg = c.overlay },
    -- The language named after a fence opener lands on @label, which would
    -- otherwise paint it in the error color.
    ["@label.markdown"] = { fg = c.muted },

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
