# Firefox transparency

Rules live in `configs/firefox/userContent.css`; window chrome in `packages/rewaita.nix`.

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
