# Choose pin identifiers and policy ownership

Type: wayfinder:grilling
Status: resolved
Blocked by: None

## Question

The current spec keeps descriptive egress tags encrypted, but a per-app pin in
Home Manager would expose its identifier in Nix. Should apps name a stable,
non-sensitive ID mapped to an encrypted tag, keep the entire app policy in
encrypted material, or make descriptive names public? Define precedence among
an app's pin, `vpn --egress`, and the runtime default; reject positional IDs
if inventory edits could silently change their meaning.

## Answer

Use explicit, stable egress names: `vpn --egress "name"`. The name is the
sing-box tag of one entry in encrypted `secrets/vpn/egresses.jsonc`; it is not
an array position or a second public alias. That file is the source of truth
for which egresses exist and for their comments and native sing-box definitions.

Encrypted `secrets/vpn/policy.jsonc` is the source of truth for policy: the
default egress per hostname and any installed application's pin. It refers to
names from the inventory; an unknown explicit name is rejected rather than
silently mapped to another egress. An app with no pin
uses the runtime default; an explicit `vpn --egress` overrides the default for
that launch. The runtime saved choice overrides only the policy's default; it
does not rewrite either JSONC file. The exact launcher lookup interface belongs
to the runtime-topology decision.

This revises the earlier idea of placing a named app pin in Home Manager:
descriptive provider/location names stay inside encrypted JSONC, as required
by the existing VPN spec. Home Manager installs and routes each app launcher
but does not duplicate private names or policy values.
