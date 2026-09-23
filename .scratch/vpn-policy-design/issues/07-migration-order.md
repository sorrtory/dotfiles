# Order the VPN rewrite and module refactor

Type: wayfinder:grilling
Status: resolved
Blocked by: 12

## Question

Translate the chosen topology into a sequence of independently verifiable
changes. Decide which parts of `.scratch/vpn-egress/spec.md` and its existing
tickets must be replaced before work starts, whether the shared VPN and app
module split precedes or accompanies backend changes, and where the
whole-host TUN enters. Every slice must leave the daily machine usable and
must not activate a new generation without operator approval.

## Answer

Use the operator's chosen order: **module split → whole-host TUN on the
current backend → concurrent-egress backend and pins**. Prepare and inspect
each generation before its host activation; activation remains a separate
operator approval. A migration commit should have one observable purpose and
leave the current commands usable after activation.

1. **Split the current module without changing behavior.** Move the shared
   `vpn` command, namespace entry, capture service and config helper behind a
   small VPN runtime module. Move Vesktop and AyuGram package replacement,
   launcher checks, and their enable options into app-owned modules. Move the
   Vesktop palette registration and live stylesheet into the theme layer,
   beside the existing Telegram theme module. Preserve the existing option
   names, launch paths, app settings and capture service behavior in this
   slice; no new egress names or pins enter Nix. Create each new file only as
   its responsibility moves. This makes the current large file a mechanical
   refactor, not part of the backend cutover.
2. **Prepare the credential-free whole-host TUN while `wg-quick` still owns
   `vpn-up`.** Add the backend's physical-interface binding and build the TUN
   config and root launcher without switching the live aliases. The TUN
   forwards through the current local SOCKS listener, so it does not require
   the inventory, selector or pins. Prove route, DNS, LAN and fail-closed
   behavior on staging, including Fedora's privileged launch path.
3. **Cut over `vpn-up`/`vpn-down` to the TUN.** Keep the one-credential backend
   and its existing local proxy and capture. Replace the identity-handover
   marker behavior, then verify normal use before retiring its code and the
   old `wg-quick` secret declarations. This removes the risk of running
   `wg-quick` with a WireGuard peer simultaneously loaded by the future
   all-egress backend. Preserve a reviewed rollback generation until the new
   path works in normal use.
4. **Introduce the encrypted inventory and compile the concurrent backend.**
   Rewrite implementation ticket 01: load all native sing-box entries in one
   user backend; compile a manual default selector, stable named listeners,
   route-specific DNS and IPv4/IPv6 policy from encrypted JSONC. Keep the
   existing local proxy addresses and a working default `vpn` capture at the
   cutover. Build and validate with synthetic data before real encrypted
   material; do not run old and new clients with the same WireGuard peer at
   once. Staging's secret-recovery gate remains an operator prerequisite for
   real credential checks there.
5. **Add runtime control, then pinned captures.** Rewrite ticket 02 into
   independently observable pieces: authenticated loopback Clash API and
   `vpn-egress` selection/status/check first; route-specific capture units,
   `vpn --egress NAME`, encrypted installed-app pins and switch reconciliation
   next. A default switch must leave a named capture alone. A Home Manager
   switch must reset the declarative default, and stop app scopes affected
   by changed pins or routes before a listener binding can change. Each
   piece must have route and namespace readback rather than infer correctness
   from process liveness.
6. **Finish evidence and retirement separately.** A real non-WireGuard egress
   stays blocked until a deployed server and credential exist. Keep the
   normal-use recovery and legacy-retirement gates in tickets 07–08; do not
   delete the old mechanisms merely because the new units start once.

Ticket 03's `sudo systemd-run` direct Nix executable design must be replaced.
On the Fedora 44 staging VM with SELinux Enforcing, a transient root service
executing the Nix sing-box binary directly failed `203/EXEC`. A root systemd
service whose first executable was host-labeled `/usr/bin/env`, passing the
Nix binary and a nonsecret temporary config as arguments, stayed active,
created a real no-route TUN interface, and stopped cleanly with that interface
removed. This supports a supervised privileged launch without a persistent
SELinux policy change; the implementation must resolve the host's labeled
`env` path and prove the full resulting TUN config. Only explicit `vpn-up`
may prompt for sudo. Home Manager activation must remain unprivileged.

A later run of the full **synthetic** TUN configuration through that same
root service passed route, DNS, selector, failure and cleanup checks. The
implementation still repeats them on its generated configuration.

Before implementation begins, replace the obsolete bodies of tickets 01–03
and the spec's stale single-egress or unverified statements, and add a
separate module-split and pin-lifecycle ticket. Keep independent AppArmor and
relative-path defects as their own tickets.

## Comments

The later `to-tickets` pass renumbered the implementation work into dependency
order. Read [the current egress map](../../vpn-egress/map.md) for ticket
numbers; the sequence and gates in this answer remain the design decision.
