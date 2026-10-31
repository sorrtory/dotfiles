# Per-site Firefox CSS controls

Research date: 2026-10-27. Captured before implementation. The repository now
prepares `configs/firefox/page-styles.user.css` for Stylus and retains native
Home/New Tab rules plus palette variables in `userContent.css`; host
activation and normal-use verification remain pending.

Native Home/New Tab preservation was subsequently verified in isolated
Firefox 158: root/body transparency and layout measurements match the prior
global rule, while an ordinary website receives no native background clearing.
The operator chose manual Stylus updates; automatic delivery remains research
only.
Descriptions of the existing clearing rules below refer to the pre-migration
baseline.

## Recommended flow

Keep page transparency enabled by default. Move page-altering rules into one
Stylus-managed style, then use its popup to temporarily disable that style in
the current tab or persistently exclude a domain. Keep Firefox chrome styling
under Rewaita and keep the generated `--dotfiles-*` palette variables in
`userContent.css` so the managed style can continue referring to theme colors.
This ownership split is a proposed migration, not an implemented change.

Stylus's official Firefox version history lists **2.4.17, released 2026-10-20**.
The stable 2.3.22 entry documents popup exclusions for a tab, domain, exact URL,
or prefix, Alt-click for a temporary tab toggle, and a configurable “Toggle
current tab” shortcut. The 2.4.2 entry adds right-click on the popup checkbox
for a tab toggle. Ordinary checkbox clicks toggle the style globally; use the
tab control or exclusion menu for this workflow. Sources:
[official Firefox version history](https://addons.mozilla.org/en-GB/firefox/addon/styl-us/versions/),
[current popup event source](https://github.com/openstyles/stylus/blob/master/src/popup/events.js).
The tagged 2.4.17 source was unavailable through the browsing tool; current
source and the stable release history agree on these controls.

## Why adding an override style is insufficient

The existing global rule clears `html`, `body`, `nav`, `.nav`, `header`,
`footer`, and `main`, and site-specific rules clear additional surfaces. A
control must stop these declarations applying rather than set `opacity: 1`:
opacity does not replace an element's transparent background. Keeping these
rules active in `userContent.css` while toggling a duplicate Stylus style would
leave the original rules applied.

Firefox loads `userContent.css` as user-origin CSS. User-origin `!important`
rules outrank author-origin `!important` rules; Stylus's normal injection uses
style elements or adopted stylesheets. Therefore the clearing rules should
move out of the active `userContent.css` when Stylus assumes responsibility.
Moving origins may change conflicts with site-specific `!important` rules;
verify representative sites before removing the old machinery. Sources:
[Firefox stylesheet cache source](https://raw.githubusercontent.com/mozilla-firefox/firefox/main/layout/style/GlobalStyleSheetCache.cpp),
[CSS cascade ordering](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascade/Introduction),
[Stylus injector source](https://raw.githubusercontent.com/openstyles/stylus/master/src/content/style-injector.js).

A custom extension could inject user-origin CSS, but `tabs.removeCSS` removes
CSS previously inserted through `tabs.insertCSS`, not the profile's existing
`userContent.css`. Sources:
[insertCSS](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/insertCSS),
[removeCSS](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/removeCSS).

## CSS-only alternative

For very rare exceptions, keep the present ownership and restrict the clearing
rules with an `@-moz-document regexp(...)` that excludes selected domains. The
exclusion must cover both the global rule and any site-specific rules affecting
that domain. Firefox supports URL regex matching in user sheets; the regex
must match the full URL and backslashes require CSS escaping. Source:
[MDN @document](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@document).

This is a static exception list, with no browser toolbar control. In this repo,
the native CSS is concatenated into `pkgs.writeText` output, so source edits
require a rebuild and activation, followed by Firefox restart. Firefox's source
loads the profile sheets into its process stylesheet cache at initialization,
and the existing module correctly advertises restart application. Sources:
[`modules/programs/firefox.nix`](../../modules/programs/firefox.nix),
[Firefox stylesheet cache source](https://raw.githubusercontent.com/mozilla-firefox/firefox/main/layout/style/GlobalStyleSheetCache.cpp).

The generated palette variables can stay separate from the switchable style;
they do not themselves clear backgrounds. Source:
[`modules/theme/firefox-content.nix`](../../modules/theme/firefox-content.nix).

## Implementation verification

On 2026-10-27 the prepared migration passed `nix flake check`, the host
activation-package build and its Firefox activation step in a scratch home.
The CSS rule body after the introductory comment is byte-for-byte identical
to the pre-migration file.

An isolated Firefox 158 profile with signed Stylus 2.4.17 parsed and installed
the actual UserCSS (20 sections), cleared fixture backgrounds by default and
resolved the ChatGPT selectors' palette variables and `color-mix()`. A domain
exclusion restored the fixture's author backgrounds and survived reload, an
ordinary style update and a browser restart. Other hostnames retained styling
after reload/restart. Saving the exclusion temporarily cleared styling in
other already-open tabs as well; reloading those tabs restored their correct
styling. This appears to be a Stylus notification issue, not a saved matching
error.

These were local HTTPS fixtures, not today's live-site DOM or wallpaper
compositing. The normal host Firefox profile was not modified. Operator
installation, approved activation and normal-use verification remain pending.

## Native new tab and automatic updates

Follow-up research on 2026-10-27; no production configuration change. The
examined upstream manifest identifies the source as Stylus **2.4.17**:
[manifest](https://raw.githubusercontent.com/openstyles/stylus/master/src/manifest.json).

### Firefox's native new tab

Stylus cannot inject into Firefox's built-in `about:newtab` or `about:home`
documents. Mozilla explicitly excludes built-in pages, including the new empty
tab page, from extension CSS injection. Recommended ownership: keep native
new-tab rules in `userContent.css`, beside the generated palette properties;
keep ordinary website styling in Stylus. New-tab rules would require the
existing Home Manager rebuild/activation and Firefox restart flow. Sources:
[Mozilla insertCSS restrictions](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/insertCSS),
[Stylus on Firefox UI](https://github.com/openstyles/stylus/wiki/Styling-Firefox-UI).

An extension can replace the new-tab document using `chrome_url_overrides`,
but this supplies a different bundled HTML page rather than styling Firefox
Home. A page supplied by another extension also cannot be styled by Stylus's
content script. Sources:
[Mozilla new-tab overrides](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/chrome_url_overrides),
[extension-page restrictions](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Content_scripts#limitations).

### Updates from a URL

The repository's current JSON export has **no update URL or original digest**,
so its installed copy is not presently wired for automatic updates. Stylus
considers a style for scheduled updates only when its top-level `updateUrl`
exists and `updatable` is not false. Its editor exposes that URL and update
checkbox under Style settings. Normal UserCSS installation maps metadata
`@updateURL` to this stored property. Our JSON importer instead compiles the
supplied `usercssData` directly; an exporter that adds this capability should
emit the top-level `updateUrl`, not only a source-code comment. Sources:
[repository exporter](../../scripts/repo/export-firefox-style.py),
[scheduler and updater](https://raw.githubusercontent.com/openstyles/stylus/master/src/background/update-manager.js),
[style settings](https://raw.githubusercontent.com/openstyles/stylus/master/src/edit/settings.js),
[UserCSS metadata mapping](https://raw.githubusercontent.com/openstyles/stylus/master/src/background/usercss-manager.js),
[JSON import compilation](https://raw.githubusercontent.com/openstyles/stylus/master/src/background/style-manager/index.js).

There is a second migration detail: scheduled updates reject styles without
an `originalDigest` as potentially edited locally. Merely adding a URL to our
existing JSON-installed style is therefore insufficient. Perform one normal
installation/reinstallation through the HTTP UserCSS installer, or use the
manager's explicit forced-update flow, to establish the baseline digest.
Use an update of the existing identity rather than reimporting JSON, which
can replace personal settings. The normal updater merges new CSS with the
existing installed style and retains exclusions and enabled state. Source:
[update checks and merge](https://raw.githubusercontent.com/openstyles/stylus/master/src/background/update-manager.js).

Possible sources, pending operator choice:

- **Public raw GitHub URL:** no local service. Edit the repository's UserCSS,
  increase `@version`, then commit and push before Stylus can receive it.
  Remote updates with an unchanged version are skipped. Publication is a
  separate operator action.
- **Loopback HTTP URL:** a user service serving only the UserCSS at a fixed
  route, bound to `127.0.0.1`, can expose saved local edits to Stylus without
  publishing them. The updater explicitly permits changed content at the same
  version for `localhost`, `127.0.0.1`, and `file:` URLs; downgrades are still
  rejected. A future implementation should serve the single file, not the
  repository directory. No service was added during this research.

The version behavior and local-host definition come from the
[updater](https://raw.githubusercontent.com/openstyles/stylus/master/src/background/update-manager.js)
and [URL helper](https://raw.githubusercontent.com/openstyles/stylus/master/src/js/urls.js).

Global update checks default to **24 hours**; setting the interval to zero
disables them. The implementation schedules no sooner than **60 seconds**
after the current time, even when configured with a shorter interval. These
checks work without keeping an installer tab open. Immediate live reload is
different: it requires the installer tab to remain open. Sources:
[preference defaults](https://raw.githubusercontent.com/openstyles/stylus/master/src/js/prefs.js),
[alarm scheduling](https://raw.githubusercontent.com/openstyles/stylus/master/src/background/update-manager.js),
[live reload documentation](https://github.com/openstyles/stylus/wiki/Writing-UserCSS#live-reload-on-the-fly-previewing).

An actual HTTP-updater browser check is being performed separately; these
follow-up statements are source-level findings until its result is recorded.
