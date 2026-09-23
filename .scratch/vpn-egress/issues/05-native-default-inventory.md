# 05: Serve the current default from encrypted native inventory

Status: ready-for-agent
Blocked by: 04 (whole-host TUN)

**What to build:** Replace the current backend's WireGuard profile source
with encrypted, commented sing-box inventory and hostname policy while
preserving its one selected default. Proxy users, default capture and the
whole-host TUN continue to work as before; concurrent loading follows in
ticket 06.

- [ ] Native egress entries and policy validate, including unique names,
      hostname coverage and missing-reference errors; operator notes survive
      encrypted editing.
- [ ] The current machine's default carries proxy TCP, captured UDP/DNS and
      whole-host traffic after cutover, with IPv4-only default behavior and
      no unbound direct outbound.
- [ ] Credentials never enter Nix evaluation, arguments, environment, logs,
      patches or the store. Old and new clients never use one WireGuard peer
      simultaneously.
- [ ] Synthetic fixture checks precede real-credential checks. Staging real
      credentials await the operator's secret recovery; daily-host activation
      is separately approved with a rollback generation available.
