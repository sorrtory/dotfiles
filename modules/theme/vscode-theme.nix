# A VS Code color theme from a resolved theme, for a palette that declares no
# native extension of its own. The editor reads this only at startup, so it is
# a store file rather than one of `dotfiles.theme.liveFiles`.
#
# The theme keeps the stable name "Dotfiles", so `workbench.colorTheme` in
# configs/vscode/settings.json never changes; what is behind the name does.
#
# Syntax colors follow the same reading of the roles as
# modules/theme/sublime-scheme.nix — comments are muted, strings succeed,
# keywords err — so an editor switch does not also mean relearning what a
# color means.

colors:
let
  inherit (colors) base mantle surface overlay text subtext muted accent accent2 error warning success info;
  inherit (colors) brightMagenta brightCyan brightBlue brightGreen brightYellow brightRed;

  # VS Code takes #rrggbbaa, so a translucent shade is the role plus two hex
  # digits. Selections and highlights have to let the text through.
  fade = alpha: color: color + alpha;

  rule = scope: settings: { inherit scope settings; };
in
builtins.toJSON {
  name = "Dotfiles";
  type = "dark";
  semanticHighlighting = true;

  colors = {
    # Editor.
    "editor.background" = base;
    "editor.foreground" = text;
    "editorLineNumber.foreground" = muted;
    "editorLineNumber.activeForeground" = subtext;
    "editorCursor.foreground" = accent;
    "editor.selectionBackground" = fade "66" overlay;
    "editor.selectionHighlightBackground" = fade "44" overlay;
    "editor.wordHighlightBackground" = fade "44" overlay;
    "editor.lineHighlightBackground" = fade "80" surface;
    "editor.findMatchBackground" = fade "66" warning;
    "editor.findMatchHighlightBackground" = fade "33" warning;
    "editorIndentGuide.background1" = surface;
    "editorIndentGuide.activeBackground1" = overlay;
    "editorWhitespace.foreground" = overlay;
    "editorRuler.foreground" = surface;
    "editorBracketMatch.background" = fade "00" base;
    "editorBracketMatch.border" = accent;
    "editorGutter.background" = base;
    "editorGutter.addedBackground" = success;
    "editorGutter.modifiedBackground" = accent;
    "editorGutter.deletedBackground" = error;
    "editorError.foreground" = error;
    "editorWarning.foreground" = warning;
    "editorInfo.foreground" = info;
    "editorCodeLens.foreground" = muted;
    "editorLink.activeForeground" = accent;

    # Bracket pairs walk the hues the palette names, so nesting reads as
    # color rather than as shades of one.
    "editorBracketHighlight.foreground1" = accent;
    "editorBracketHighlight.foreground2" = accent2;
    "editorBracketHighlight.foreground3" = brightYellow;
    "editorBracketHighlight.foreground4" = brightGreen;
    "editorBracketHighlight.foreground5" = brightCyan;
    "editorBracketHighlight.foreground6" = brightMagenta;
    "editorBracketHighlight.unexpectedBracket.foreground" = error;

    # Workbench chrome. The title bar and tab strip take the headerbar shade
    # so the window matches what the desktop theme draws above it.
    "titleBar.activeBackground" = mantle;
    "titleBar.activeForeground" = text;
    "titleBar.inactiveBackground" = mantle;
    "titleBar.inactiveForeground" = muted;
    "titleBar.border" = surface;
    "editorGroupHeader.tabsBackground" = mantle;
    "editorGroupHeader.noTabsBackground" = base;
    "editorGroup.border" = surface;
    "tab.activeBackground" = base;
    "tab.activeForeground" = text;
    "tab.inactiveBackground" = mantle;
    "tab.inactiveForeground" = muted;
    "tab.border" = mantle;
    "tab.activeBorderTop" = accent;
    "tab.hoverBackground" = surface;

    "activityBar.background" = mantle;
    "activityBar.foreground" = text;
    "activityBar.inactiveForeground" = muted;
    "activityBar.border" = surface;
    "activityBarBadge.background" = accent;
    "activityBarBadge.foreground" = base;

    "sideBar.background" = mantle;
    "sideBar.foreground" = subtext;
    "sideBar.border" = surface;
    "sideBarTitle.foreground" = text;
    "sideBarSectionHeader.background" = surface;
    "sideBarSectionHeader.foreground" = text;

    "statusBar.background" = mantle;
    "statusBar.foreground" = subtext;
    "statusBar.border" = surface;
    "statusBar.noFolderBackground" = mantle;
    "statusBar.debuggingBackground" = accent;
    "statusBar.debuggingForeground" = base;
    "statusBarItem.remoteBackground" = accent;
    "statusBarItem.remoteForeground" = base;

    "panel.background" = base;
    "panel.border" = surface;
    "panelTitle.activeForeground" = text;
    "panelTitle.inactiveForeground" = muted;

    "terminal.background" = base;
    "terminal.foreground" = text;
    "terminal.ansiBlack" = colors.black;
    "terminal.ansiRed" = colors.red;
    "terminal.ansiGreen" = colors.green;
    "terminal.ansiYellow" = colors.yellow;
    "terminal.ansiBlue" = colors.blue;
    "terminal.ansiMagenta" = colors.magenta;
    "terminal.ansiCyan" = colors.cyan;
    "terminal.ansiWhite" = colors.white;
    "terminal.ansiBrightBlack" = colors.brightBlack;
    "terminal.ansiBrightRed" = brightRed;
    "terminal.ansiBrightGreen" = brightGreen;
    "terminal.ansiBrightYellow" = brightYellow;
    "terminal.ansiBrightBlue" = brightBlue;
    "terminal.ansiBrightMagenta" = brightMagenta;
    "terminal.ansiBrightCyan" = brightCyan;
    "terminal.ansiBrightWhite" = colors.brightWhite;

    # Popups, lists and inputs.
    "dropdown.background" = surface;
    "dropdown.foreground" = text;
    "dropdown.border" = overlay;
    "input.background" = surface;
    "input.foreground" = text;
    "input.border" = overlay;
    "input.placeholderForeground" = muted;
    "inputOption.activeBorder" = accent;
    "inputValidation.errorBackground" = surface;
    "inputValidation.errorBorder" = error;

    "list.activeSelectionBackground" = overlay;
    "list.activeSelectionForeground" = text;
    "list.inactiveSelectionBackground" = surface;
    "list.inactiveSelectionForeground" = text;
    "list.hoverBackground" = surface;
    "list.hoverForeground" = text;
    "list.highlightForeground" = accent;
    "list.errorForeground" = error;
    "list.warningForeground" = warning;

    "quickInput.background" = mantle;
    "quickInput.foreground" = text;
    "editorWidget.background" = mantle;
    "editorWidget.border" = overlay;
    "editorHoverWidget.background" = mantle;
    "editorHoverWidget.border" = overlay;
    "editorSuggestWidget.background" = mantle;
    "editorSuggestWidget.border" = overlay;
    "editorSuggestWidget.selectedBackground" = overlay;
    "editorSuggestWidget.highlightForeground" = accent;
    "peekViewEditor.background" = mantle;
    "peekViewResult.background" = mantle;

    "button.background" = accent;
    "button.foreground" = base;
    "button.hoverBackground" = accent2;
    "badge.background" = accent;
    "badge.foreground" = base;
    "progressBar.background" = accent;
    "focusBorder" = accent;
    "foreground" = text;
    "descriptionForeground" = muted;
    "errorForeground" = error;
    "widget.shadow" = fade "80" mantle;

    "scrollbarSlider.background" = fade "66" overlay;
    "scrollbarSlider.hoverBackground" = fade "99" overlay;
    "scrollbarSlider.activeBackground" = overlay;

    "menu.background" = mantle;
    "menu.foreground" = text;
    "menu.selectionBackground" = overlay;
    "menu.separatorBackground" = surface;
    "menubar.selectionBackground" = overlay;

    "notificationCenterHeader.background" = mantle;
    "notifications.background" = mantle;
    "notifications.border" = overlay;

    # Diffs, Git and problems, which use the same four meanings everywhere.
    "diffEditor.insertedTextBackground" = fade "22" success;
    "diffEditor.removedTextBackground" = fade "22" error;
    "gitDecoration.addedResourceForeground" = success;
    "gitDecoration.modifiedResourceForeground" = accent;
    "gitDecoration.deletedResourceForeground" = error;
    "gitDecoration.untrackedResourceForeground" = success;
    "gitDecoration.ignoredResourceForeground" = muted;
    "gitDecoration.conflictingResourceForeground" = warning;
    "problemsErrorIcon.foreground" = error;
    "problemsWarningIcon.foreground" = warning;
    "problemsInfoIcon.foreground" = info;

    "textLink.foreground" = accent;
    "textLink.activeForeground" = accent2;
    "textPreformat.foreground" = brightCyan;
    "breadcrumb.foreground" = muted;
    "breadcrumb.focusForeground" = text;
    "breadcrumbPicker.background" = mantle;
  };

  tokenColors = [
    (rule [ "comment" "punctuation.definition.comment" ] { foreground = muted; fontStyle = "italic"; })
    (rule [ "string" "string.quoted" ] { foreground = success; })
    (rule [ "constant.character.escape" "string.regexp" ] { foreground = accent; })
    (rule [ "constant.numeric" "constant.language" "constant.character" "constant.other" ] { foreground = brightMagenta; })
    (rule [ "keyword" "storage.modifier" "keyword.control" ] { foreground = error; })
    (rule [ "keyword.operator" ] { foreground = text; })
    (rule [ "keyword.control.import" "keyword.control.from" "meta.preprocessor" ] { foreground = brightCyan; })
    (rule [ "storage.type" "entity.name.type" "entity.name.class" "support.type" "support.class" "entity.other.inherited-class" ] { foreground = warning; })
    (rule [ "entity.name.function" "support.function" "variable.function" "meta.function-call" ] { foreground = success; fontStyle = "bold"; })
    (rule [ "variable.parameter" ] { foreground = accent2; })
    (rule [ "variable.language" "support.constant" ] { foreground = accent; })
    (rule [ "variable.other.property" "meta.object-literal.key" "support.type.property-name" ] { foreground = accent2; })
    (rule [ "variable" "variable.other" ] { foreground = text; })
    (rule [ "entity.name.tag" ] { foreground = brightCyan; })
    (rule [ "entity.other.attribute-name" ] { foreground = warning; })
    (rule [ "punctuation.definition.tag" ] { foreground = accent2; })
    (rule [ "entity.name.section" "markup.heading" ] { foreground = success; fontStyle = "bold"; })
    (rule [ "markup.bold" ] { fontStyle = "bold"; })
    (rule [ "markup.italic" ] { fontStyle = "italic"; })
    (rule [ "markup.underline.link" "markup.link" ] { foreground = accent2; })
    (rule [ "markup.inline.raw" "markup.raw" ] { foreground = brightCyan; })
    (rule [ "markup.quote" ] { foreground = muted; fontStyle = "italic"; })
    (rule [ "markup.list punctuation.definition.list.begin" ] { foreground = accent; })
    (rule [ "markup.inserted" ] { foreground = success; })
    (rule [ "markup.deleted" ] { foreground = error; })
    (rule [ "markup.changed" ] { foreground = accent; })
    (rule [ "invalid" ] { foreground = error; })
    (rule [ "invalid.deprecated" ] { foreground = warning; })
  ];
}
