-- The colorscheme for a theme that declares no plugin of its own. Being a
-- real colorscheme rather than a pile of highlight calls is what makes
-- `:colorscheme dotfiles` work and what fires the ColorScheme event other
-- plugins, transparent.nvim among them, listen for.
require("theme.generated").apply(require("theme").colors)
