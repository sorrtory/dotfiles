# 14 — Markdown in the generated colorscheme

Type: task
Status: resolved
Blocked by: 03

## What to build

Under autumn-leaves a Markdown file is two colors. Measured from a real
buffer, every capture the Markdown parser produces resolves to one of four
roles, three of which are neighbours on the wheel:

| what | group | role | hue |
| --- | --- | --- | --- |
| every heading level | `@markup.heading.1-6` | accent | 20° |
| list markers, checkboxes | `@markup.list*` | accent | 20° |
| quote text and its `>` | `@markup.quote`, `@punctuation.special` | accent | 20° |
| links, label and URL | `@markup.link*` | accent2 | 29° |
| inline and fenced code | `@markup.raw*` | success | 49° |
| a fence's language | `@label` | error | 8° |

Headings, bullets and quotes are the same hex, so a heading does not read as
one; a link is nine degrees from a heading, which the eye takes for the same
color at a different brightness. The palette's two cool roles reach nothing
but a `:terminal` buffer, and they stay that way: a foreign hue is not
autumn-leaves, so the separation has to come from the roles already there and
from texture.

- Heading levels told apart, as a leaf turning rather than as six hues.
- Links separated from headings.
- Quotes, list markers and fenced blocks each distinguishable from a heading.
- The prose itself untouched at every depth.

## Acceptance

- [x] The four heading levels a document actually uses resolve to four
      distinct colors, each derived from a role.
- [x] A link, a quote, a list marker and inline code are each a different
      color from every heading.
- [x] The check parses a real Markdown buffer, so a group named in the
      colorscheme that the parser never produces fails it.

## Comments

The ramp's direction and its rungs were settled by measurement rather than by
eye; the numbers are in the Answer.

## Answer

`configs/nvim/lua/theme/generated.lua` now maps Markdown's own captures, and
`tests/theme_nvim_test.sh` parses a sample buffer and asserts the eight
captures it names are captured at all and resolve to eight distinct colors.

The heading ramp is maple red, copper, amber, green over H1–H4, with H5 and H6
in muted. It is tuned by `blend`, the Lua twin of `modules/theme/color.nix`'s
`mix`, so the rungs stay a statement about roles:

| level | role | derivation | result |
| --- | --- | --- | --- |
| H1 | error | `mix error base 0.14` | `#cd5644` |
| H2 | accent | `mix accent text 0.10` | `#d67c4f` |
| H3 | accent2 | `mix accent2 base 0.06` | `#dd995a` |
| H4 | info | `mix info text 0.06` | `#9dcb79` |

Three things decided its shape:

- **Brightness cannot carry the hierarchy.** The roles run 0.260, 0.256,
  0.436, 0.419, 0.496 in relative luminance, which rises with depth. Forcing
  it to descend means lifting red toward the cream, which washes it to salmon
  `#ee8977` at 0.58 saturation and still does not out-brighten amber. It does
  not need to: Markview draws no preview, so the `#` of each heading are on
  screen and counting them is how a level is read. That frees the ramp to be
  the theme's metaphor, and the nudges above are only large enough that
  neighbouring levels differ by 1.14 to 1.37 in contrast on top of their hue.
- **It stops at four.** This repository's Markdown holds 129 H1, 532 H2, 85 H3
  and 10 H4, and no H5 or H6 at all. A six-rung ramp spends its most visible
  colors on levels nothing writes, and shows only red, copper and amber —
  21° of hue — in practice.
- **Gold is not in it.** Inline code is 375 occurrences per 1000 lines of
  Markdown here, five times the headings and twelve times the links, so
  `success` is the busiest color on a page and cannot also be a heading level.
  For the same reason it keeps a plain foreground: a background chip on 375
  spans per 1000 lines stipples the page. The chip goes to fenced blocks
  instead, which carry `surface` and no foreground, since the injected
  language already colors what is inside them.

The rest separates by texture rather than hue, there being no hue left:

- A link's label is `text` underlined and its URL `muted` underlined, the
  brackets `muted`. Underline is the oldest affordance for "this leaves the
  document" and it costs the palette nothing.
- Quotes are `muted` italic, and their `>` — with the `---` of a thematic
  break — is `overlay`, through `@punctuation.special.markdown` so that a
  format specifier in a string keeps `Special`.
- List markers are `subtext`, a checked box `info` and an unchecked one
  `muted`.
- A fence's language is `muted` through `@label.markdown`, which was the error
  color by accident of where the capture lands.

Not done, and deliberately: `@markup.strong` and `@markup.italic` keep the
text color and carry only their weight. Emphasis happens inside sentences, and
coloring it colors the prose.
