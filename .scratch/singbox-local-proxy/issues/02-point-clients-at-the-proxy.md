# 02 — Point Firefox and VS Code at the local proxy

Status: ready-for-agent

Blocked by: 01

## Goal

Make the browser and the editor use `127.0.0.1:1080`, preserving the routing
policy the PAC file already expresses, without making the proxy system-wide.

## Work

1. Set Firefox to PAC mode rather than manual proxy:
   - `network.proxy.type = 2`
   - `network.proxy.autoconfig_url = "file:///home/z/Documents/secrets/proxy.pac"`
   The PAC returns `PROXY 127.0.0.1:1080`, which is an HTTP-proxy directive;
   the `mixed` inbound from ticket 01 answers it on the same port it serves
   SOCKS. Drop the legacy manual-proxy prefs (`network.proxy.http`,
   `http_port`, `ssl`, `ssl_port`, `socks`, `socks_port`) — the PAC decides.
   Keep `network.proxy.socks_remote_dns = true`, which costs nothing and
   applies if the PAC ever returns a `SOCKS5` directive.
2. Carry over the non-proxy prefs from the legacy `FIREFOX_PREFERENCES`
   (`browser.tabs.insertAfterCurrent`, `browser.ctrlTab.sortByRecentlyUsed`).
3. Write those prefs with an idempotent Home Manager activation script that
   locates the profile directory by glob under
   `~/snap/firefox/common/.mozilla/firefox/*.default*/` and writes `user.js`.
   The directory name is random, so it cannot be a static file declaration.
   Re-running must converge rather than append. This is deliberately the
   legacy approach made re-runnable; the `firefox-nix` effort replaces it.
4. Add `"http.proxy": "socks5://127.0.0.1:1080"` to the managed VS Code
   settings established by the `package-migration` effort.

## Constraints

- Do not export `HTTP_PROXY`, `HTTPS_PROXY` or `ALL_PROXY` in the login shell
  or any profile snippet. Doing so would route `apt`, `nix`, `curl` and every
  other CLI through the tunnel and destroy the property this whole design
  exists for. If a specific VS Code extension needs the variable, scope it to
  that process, never to the session.
- The PAC path must stay a non-hidden directory under the real home. The
  Firefox snap's `home` interface denies hidden paths: reading
  `/home/z/.bashrc` or `/home/z/.config/...` from inside the snap returns
  `Permission denied`, and `/run/user/1000/secrets.d/...` likewise. This is
  why the PAC's encryption is deferred to `firefox-nix` rather than solved
  here — a sops-rendered path is unreadable by a confined Firefox.
- Do not relocate or rewrite `proxy.pac` in this ticket.

## Acceptance

- Firefox reaches the internet through the proxy for a default-policy domain,
  and directly for a domain the PAC routes `DIRECT` (`.ru`, `yandex.*`).
- A domain on the PAC block list fails to load.
- `apt` and `nix` still work with no proxy configuration in the environment.
- Re-running activation twice leaves a single correct `user.js`.
