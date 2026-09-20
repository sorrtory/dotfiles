# 06 — Spotify

Type: task
Status: resolved
Blocked by: 01

## What to build

Spotify's Spicetify color scheme comes from the resolved palette.

- Autumn-glass reproduces today's scheme exactly.
- Spotify registers as "restart to apply" in the hint.

## Acceptance

- [x] Rendered autumn-glass colors equal today's scheme.
- [x] Each theme builds and shows its colors after a Spotify restart.
- [x] A Spotify override in `home.nix` takes effect.

## Comments

## Answer

Built in `modules/theme/spotify-scheme.nix`, read by
`modules/programs/spotify.nix`; `tests/theme_spotify_test.sh` covers all three
acceptance lines, the autumn-glass one as a diff against the eighteen values
the module carried before.

- Fourteen of Spicetify's eighteen slots are a role. The other four — the
  card, its shadow, the neutral "misc" line and the hover fill above a
  selection — are a step between two roles, so they are mixes; `mix` moved
  out of `modules/theme/rewaita-css.nix` into `modules/theme/color.nix`,
  which both now import.
- The derived mixes land within a few units of the hand-picked shades
  (`3a2621` against `3a251f`, `70564b` against `725046`), close enough for a
  theme that never had those values but not identical, so autumn-glass pins
  all four in `overrides.spotify.scheme` along with the stock `#f6e9da` text
  ticket 01's answer asked for. Every other slot comes from the roles, in
  every theme.
- `scheme` is this app's escape hatch for its own key names, as `highlights`
  is for Neovim and `colorCustomizations` for VS Code.
- Spotify registers as "restart to apply": Spicetify bakes the scheme into
  the client's CSS at activation, and the client reads it at launch.
