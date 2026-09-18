# Obsidian themes

`autumn-glass` carries the palette of the AyuGram theme in
`../ayugram/autumn-glass` as solid colors, for dark mode.

Vaults stay machine-local, so link the theme into each vault by hand:

```bash
mkdir -p <vault>/.obsidian/themes
ln -s ~/Documents/dotfiles/configs/obsidian/autumn-glass "<vault>/.obsidian/themes/Autumn Glass"
```

Then pick **Autumn Glass** under Settings → Appearance → Themes, with the base
color scheme set to dark. Obsidian does not reload the theme through the
symlink, so restart it after editing `theme.css`.
