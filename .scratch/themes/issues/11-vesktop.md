# 11 — Vesktop

Type: task
Status: resolved
Blocked by: 01

## What to build

Vesktop follows the palette like every other themed app, and the transparency
switch reaches its window.

- A generated Vencord theme at the fixed path Vencord reads, named "Dotfiles"
  like Sublime's, VS Code's and Obsidian's.
- Whether it is enabled is Vencord's own settings file, which Vencord rewrites
  itself, so enabling it is a one-time step and the hint reports it until it
  is done, as Obsidian's vault link is.
- A decision on transparency: Vencord can make the window translucent, unlike
  Spotify and VS Code, so the ticket has to say whether it should.

## Acceptance

- [x] Each palette renders a theme whose window, panels, text and accent are
      that palette's roles.
- [x] A switch recolors a running client, without restarting it.
- [x] The hint names Vesktop until the theme is enabled, and stays quiet
      afterwards.
- [x] Transparency reaches the window, whichever way the ticket settles.

## Comments

Vesktop's own `settings.json` stays a live-editable file in `configs/vesktop/`
(ticket 03 of the VPN effort), and Vencord's is a second, separate file under
`settings/`. Neither is generated here.

**2026-09-23 — the visual refresh had moved the families out from under it.**
The generated theme was enabled and applied, and almost nothing took the
palette's colors. The six families it wrote are the numbering Discord used
before the visual refresh. The refreshed client keeps that numbering alive but
derives it: its stylesheet declares a second set of families on `:root` —
`--neutral-1` to `--neutral-100`, `--blurple-*`, `--red-new-*` and the rest, a
hundred steps each — and a `.visual-refresh` class that reads
`--primary-600: var(--neutral-69)` for the component styles that still name
the old ones. `.theme-dark` itself was rewritten onto the new families: of its
624 declarations, 171 come from the neutral family and 16 from the old
numbered one, which is what the operator was seeing.

Counted the other way, the six families reached about 31 of those 624; the
families below reach about 620. What is left stock is `--white`, `--black`,
`--transparent` and the gradients Discord paints its promotional tiles and
banners with, which are artwork rather than chrome.

- **The new families are written the same way the old ones are.** The neutral
  family is the roles' own walk at the indices the refreshed client reads them
  — message text at 4, the quieter text at 16 and 23, the channel list's names
  at 28, the wash at 50, a raised surface at 64, the window at 69, the server
  bar at 73 — and each colored one is the old family it replaced put on the
  new numbering through Discord's own translation, lifted from the
  `.visual-refresh` block: for every old step, the new index it became. Where
  several old steps crowd onto one index the darkest wins, which is the value
  Discord's own family has there; every index between two of them is mixed
  from both, and the ends carry on to white and black.
- **The washes are a family of one color.** Discord writes a hover or a
  callout as `hsl(var(--opacity-12-hsl)/0.12)` — the step number names the
  alpha, not a shade, and every step of `--opacity-*` is the same color. So
  those get the triple alone; a hex there would paint an opaque block.
- **The ANSI palette reaches code blocks.** `--ansi-cyan` is
  `var(--teal-new-39)`, `--ansi-magenta` is `var(--pink-52)`, and the bright
  half is read from Discord's seven-step illustration families. Adding teal,
  orange, pink and the illustration families puts the palette's own sixteen
  colors where Discord reads them, without naming a token.
- **`:root:root`.** A class outranks a bare `:root`, and `.visual-refresh` is
  a class that re-derives the old families from the new. Doubling the
  pseudo-class puts the block above it, so a step is the color the palette
  chose whichever way the client reaches it, and the result no longer depends
  on where Vencord happens to inject the stylesheet among Discord's own.
- The new test walks every family at every step in one pass rather than
  spawning a subprocess per step, which is what makes 1158 declarations per
  palette affordable to check.

## Answer

Built in `modules/theme/vesktop-theme.nix`, read by the Vesktop block of
`modules/programs/vpnized-apps/default.nix`, where Vesktop is installed;
`tests/theme_vesktop_test.sh` covers the acceptance lines.

- **Families, not tokens.** Discord names a few hundred semantic variables —
  `--background-base-lower`, `--text-muted`, `--bg-surface-raised` — but each
  one is a step of a numbered family: `--background-base-lower:
  var(--neutral-69)`, `--background-mod-normal: hsl(var(--opacity-16-hsl)/
  0.16)`. The families are declared on `:root` and the `.theme-dark` class only
  maps tokens onto them, so the theme writes the families Discord derives
  everything from and never names a token. Tokens this file has never heard of
  follow, and so do the renames Discord ships on its own schedule. Each step is
  written twice, as the exact hex and as the hsl triple Discord mixes its
  translucent washes from, `--saturation-factor` included so Discord's
  saturation slider still works.
- **Both numberings.** Discord's older one runs 100 to 900, a step's number
  being its lightness from near-white to black, which is our roles' own order,
  so that neutral family is the walk: text at 230, subtext at 330, muted at
  360, overlay at 500, surface at 560 (the message box), base at 600 (the
  window), mantle at 660, and steps toward black below it. Its colored families
  are one role dropped where Discord reads it with the stock ramp transposed
  around it: the accent at 500, where Discord paints its buttons, and error,
  warning, success and the second accent at 360, where Discord reads them as
  text. Anchoring those four at 500 instead washed them out — their lightened
  text steps came out pastel, because a palette's error is already a color
  meant to be read on a dark panel. The visual refresh replaced that numbering
  with a hundred-step one, which is what `.theme-dark` reads now; the comment
  above records what changed and how the new families are placed.
- **Live, without a restart.** Vencord watches its themes directory
  (`fs.watch` in `vencordDesktopMain.js`) and the renderer re-fetches each
  enabled theme with a cache-busting `?v=` when it fires, so the theme is one
  of `dotfiles.theme.liveFiles` and a switch recolors a running client. This
  is why the file is copied into place rather than symlinked: a watcher sees
  the write.
- **Transparency comes from the compositor**, as it does for Obsidian. Vencord
  has a window-transparency switch, so Vesktop could draw a see-through window;
  it stays off for the reason ticket 08 recorded — Chromium redraws such a
  window with glitches on GNOME Wayland while it moves, and the operator has
  had the same trouble with every Electron application here — and because
  upstream's own description adds that it "stops the window from being
  resizable as a side effect". Blur my Shell whitelists `Vesktop` and
  `vesktop` beside Spotify, Sublime Text, VS Code and Obsidian, so the
  stylesheet is solid colors only and identical with transparency on and off.
- **What is enabled stays Vencord's.** `enabledThemes` lives in
  `~/.config/vesktop/settings/settings.json`, which Vencord rewrites whenever
  a setting changes, so activation does not touch it. The check reads the list
  back with `jq` and reports until `Dotfiles.css` is in it; a machine where
  Vesktop has never started is silent.
- A palette can still reach a token no family covers, through
  `overrides.vesktop.variables."--text-link"`, the escape hatch `scheme` is
  for Spotify and `variables` is for Obsidian. None of the three palettes
  needs one.
- Left alone: Vesktop's splash colors. They are two keys in its own
  `settings.json`, which is live-editable in `configs/vesktop/` so the UI can
  write to it, so the theme cannot own them; they show for the second or two
  before the client loads.
- For ticket 09: Vesktop belongs in the README's table as a live app, and in
  whatever `docs/DECISIONS.md` ends up saying about which windows are faded
  from outside and why.
