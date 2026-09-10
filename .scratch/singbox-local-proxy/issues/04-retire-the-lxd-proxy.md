# 04 — Retire the LXD proxy machinery

Status: ready-for-agent

Blocked by: 02

## Goal

Delete the legacy proxy outright. The flow is dedicated to fresh bootstrap, so
there is no dormant-rollback state to preserve.

## Work

1. On the host, destroy the container and its storage: `lxc delete --force
   ssProxy`. Confirm no other container depends on the derived bridge address.
2. Remove the host `shadowsocks-rust` snap, which also disposes of the
   untracked `ssserver` process that `snap services` reports inactive while it
   holds 13 MB and listens on nothing.
3. In the legacy `scripts` repository — separate from this one, so this is a
   cross-repository step — remove `setup_external_proxy`, `setup_firefox`,
   their `proxy` and `firefox` dispatch cases, their help entries, and the
   `externalProxy` branch of `do_check`. Remove `SSSERVER_CONF`,
   `SSLOCAL_CONF`, `VPN_CONTAINER_NAME`, `VPN_CONTAINER_IP_HOST` and the
   proxy lines of `FIREFOX_PREFERENCES` from `install.conf`.
4. Record the retirement in `docs/MIGRATION.md` under "Legacy retirement",
   naming what was deleted and what replaced it.
5. Decide LXD's fate separately and record it: if no other use remains, the
   `lxd` snap and the `lxd` group membership are themselves candidates for
   removal, and dropping them removes a privileged daemon from the host.

## Constraints

- Do not run this before ticket 02's acceptance passes. "Verified" means that
  acceptance, not a soak period.
- Do not delete the WireGuard profiles in `~/Documents/secrets/wireguard/`.
  Ticket 01 encrypts selected ones into this repository; the originals remain
  the operator's material.
- `ssProxy` holds the `laptop` peer. Ensure nothing else is using that peer
  at deletion time.

## Acceptance

- `lxc list` no longer shows `ssProxy`; `snap list` no longer shows
  `shadowsocks-rust`.
- No process listens on `127.0.0.1:3128`, and `1080` is served by `sing-box`.
- Firefox and VS Code still work unchanged after the deletion.
- The legacy installer no longer offers a `proxy` phase.
