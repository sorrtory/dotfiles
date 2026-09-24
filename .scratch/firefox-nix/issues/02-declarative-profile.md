# 02 — Declarative preferences and extensions

Status: needs-triage

Blocked by: 01

## Goal

Replace the glob-and-write `user.js` script with a declared profile.

## Work

1. Define a named profile through Home Manager's Firefox module, with the
   preferences carried over from the legacy `FIREFOX_PREFERENCES`: the PAC
   proxy settings, `browser.tabs.insertAfterCurrent`,
   `browser.ctrlTab.sortByRecentlyUsed`, and
   `network.proxy.socks_remote_dns`.
2. Declare the extension set. Select deliberately rather than mirroring
   whatever is installed; userscripts belong to the `monkeys` repository.
3. Replace the current native-profile activation link in
   `modules/programs/firefox.nix` and confirm the prefs still apply.

## Constraints

- Do not manage cookies, history or logins.
- Preferences that only matter on one machine do not belong here.

## Acceptance

- A fresh activation produces a working profile with the intended prefs and
  extensions, with no imperative script involved.
