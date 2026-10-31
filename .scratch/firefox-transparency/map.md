# Firefox transparency

Rules live in `configs/firefox/page-styles.user.css`, installed in Stylus;
window chrome stays in `packages/rewaita.nix`. `userContent.css` supplies
palette variables and the native Home/New Tab rules after the prepared Home
Manager generation is activated. `configs/firefox/userContent.css` keeps the
original clearing selectors scoped to `about:home` and `about:newtab`, so they
cannot defeat Stylus exclusions on websites.

The operator chose explicit style updates because they are infrequent. No
automatic update service or activation-time JSON generation is being added.
Firefox's frame and layout continue to come from Rewaita's `userChrome.css`.

Native preservation checked in isolated Firefox 158 on 2026-10-27: Home/New
Tab root and body stay transparent, with dimensions, display, margins and
padding matching the previous global rules. Settings retain their native
opaque background, and an ordinary website fixture keeps its author root,
body, navigation and main backgrounds. Palette variables remain available.

## Stylus handoff

Prepared in the repository; host activation and normal-use verification remain
pending. Install Stylus and the local style before activating the generation,
then fully restart Firefox. Verify the usual websites, a temporary tab toggle,
and a saved domain exclusion before retiring the previous generation. The
selectors are preserved; browser checks must account for Stylus's author-origin
CSS replacing user-origin `!important` declarations.

Validated on 2026-10-27: `nix flake check`, the host activation-package build,
and the generated Firefox activation step against a scratch home passed.
An isolated Firefox 158 profile with signed Stylus 2.4.17 installed the style,
resolved the palette variables, and retained a domain exclusion across page
reload, style update and browser restart. Local HTTPS fixtures exercised the
selectors; current live-site DOM and wallpaper compositing remain unverified.
Saving an exclusion also temporarily cleared styling in other already-open
tabs; reloading those tabs restored it without changing the saved exclusion.

The actual UserCSS install handoff was checked separately after the operator
reported the manager requesting JSON. That importer accepts backups, not a
`.user.css` file. Direct local-file navigation showed raw CSS but did not open
the installer in the test profile, and an explicit installer URL could not
fetch it. The real manager's Import file control accepted a clean one-style
JSON with the current source, metadata and placeholder sections, compiling all
20 sections and applying transparency to the fixture. The durable export is
`configs/firefox/page-styles.json`, regenerated from the native source by
`python3 scripts/repo/export-firefox-style.py`. It contains no fixture
exclusions or browser settings. JSON reimport replaced saved exclusions in
the actual importer test, so updates to an installed style use its UserCSS
editor; the JSON serves initial installation.

## Altered websites

| Website | Component | Description | Verified |
|---|---|---|---|
| all | `html`, `body` | page background cleared | yes |
| google.com/search | `#searchform` (`.CvDJxb`) | header bar, blurred | no |
| google.com/search | `[data-lhoverlay]` (`.RDmXvc`) | AI Overview fade trail | no |
| google.com/search | `.Zze5V` | unidentified | no |
| youtube.com | `ytd-app`, guide, chip bar | page, sidebar, filter chips | yes |
| youtube.com | `ytd-masthead #background` | top bar, blurred | yes |
| youtube.com | `#frosted-glass.ytd-app` | header + chip bar backdrop, 80% fill removed, blur kept | no |
| github.com | `.GlobalNav`, `.AppHeader` | header, blurred | no |
| chatgpt.com | `#stage-slideover-sidebar` | left panel | no |
| chatgpt.com | `#page-header`, its `[role=radiogroup]`, `.translucent-surface` | top bar, Chat/Work switch fills | no |
| chatgpt.com | `#conversation-header-actions` | Share/More button pill | no |
| chatgpt.com | `.bg-surface-primary:has(li[data-suggestion-index])` | suggestion list under composer | no |
| chatgpt.com | `#thread-bottom-container`, `[class*=threadFooterContentFade]` | composer strip and dark fade above it | no |
| chatgpt.com | `#thread-bottom .bg-surface-primary` | black panel under composer | no |
| chatgpt.com | `[data-composer-surface]` | input box, 55% tint and blur | no |
| chatgpt.com | `[data-testid=thread-disclaimer]` | "can make mistakes" + cookie link, hidden | no |
| open.spotify.com | `--background-base`, `.Root` grid, `footer nav` | all panels, player bar, footer | yes |
| vk.ru, vk.com | `#page_header_cont`, `#page_header` | top header, blurred, bottom border removed | no |
| vk.ru, vk.com | `#reforged-root` | messenger card outline (looked like header border) removed | no |
| vk.ru, vk.com | `#page_body`, `.MEApp*`, `.ConvoList*`, `.VKCOMMessenger__reforgedRightColumn` | page, messenger panels, chat list | no |
| vk.ru, vk.com | `.ConvoMain*`, `.ConvoHeader`, `.ConvoHistory`, `.ConvoComposer`, `.RightPanel*` | open conversation; input box keeps its fill | no |
| vk.ru, vk.com | `[data-testid=rightmenu]`, `rightmenuitem` | messenger folder menu | no |
| web.telegram.org | `[class*=_IsPattern]` | chat wallpaper layer, faded out | no |
| web.telegram.org | `.sidebar-slider-item`, `#chatlist-container`, `.chatlist`, `.connection-status-bottom` | sidebars and chat list | no |
| web.telegram.org | `.folders-tabs-gradient` | fade under folder tabs | no |
| claude.ai | `--cds-surface-0/1`, `--cds-page-bg` | page and sidebar | no |
