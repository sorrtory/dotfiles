# VPNized applications — existing VPN effort

Provide dotfiles.vpnizedApps.vesktop.enable: install Vesktop and route its
managed launch paths through the shared sing-box namespace flow.
See [spec.md](spec.md). This is a revision of the same effort, not a third flow.

## Frontier

[02: Private DNS and secret boundary](issues/02-dns-from-the-tunnel.md), verified
together with ticket 03 on a freshly bootstrapped staging VM. Ticket 00 records
the voice-call gate and the decisions taken closing it; ticket 01 the refactor.

## Tickets

- [00: Prototype and Vesktop compatibility](issues/00-sing-box-namespace-prototype.md) — resolved; voice call confirmed on staging.
- [01: Module-owned lifecycle and simplification](issues/01-namespace-lifecycle.md) — resolved; vpnized-apps module, `vpn` command, `dotfiles.vpn.identity`.
- [02: Private DNS and secret boundary](issues/02-dns-from-the-tunnel.md) — ready-for-agent; blocked by 01.
- [03: Install Vesktop and wrap managed launch paths](issues/03-run-as-the-user.md) — ready-for-agent; blocked by 01, 02.
- [04: Prevent untunneled Vesktop handoff](issues/04-refuse-to-lie.md) — ready-for-agent; blocked by 03.
- [05: Everyday Vesktop and failure verification](issues/05-verify-the-launcher-families.md) — ready-for-agent; blocked by 04.
- [06: Documentation, review and gated retirement](issues/06-package-and-document.md) — ready-for-agent; blocked by 05.

Ready-for-agent means specified, not permission to skip listed dependencies.
Ticket filenames are retained even where the old title described broader scope.

## Settled boundaries

One shared tunnel backend and exclusive peer identity per machine. Capture is a
second sing-box process without its own WireGuard connection. No host-wide VPN,
direct fallback, root payload or automatic proxy settings for unrelated apps.

Private shell helpers live beside the owning module; scripts/bin/ holds the
user-facing `vpn` command. Other Electron app families and multiple identities
are follow-up work in `.scratch/vpn-followups/`. Existing prototype tests are
reused. Machines are bootstrapped fresh, so there is no legacy coexistence.
