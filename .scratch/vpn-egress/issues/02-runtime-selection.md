# 02 — Switch egress at runtime with `vpn-egress`

Status: ready-for-agent

Blocked by: 01

## Goal

Let the operator change the active egress without editing anything, by saving
a choice and restarting the backend.

## Interface

```text
vpn-egress              # list every egress with its notes, active one marked
vpn-egress status       # active egress, and whether it is saved or the default
vpn-egress use EGRESS   # save a choice and apply it
vpn-egress default      # clear the saved choice and apply the default
```

## Work

1. Package `vpn-egress` from `scripts/bin/`, like the `vpn` command. It reads
   the decrypted inventory that sops-nix already rendered, so it never calls
   `sops` and never holds a key.
2. Save the choice in the user's state directory so it survives a reboot. The
   default applies only when nothing is saved.
3. Applying a choice restarts the user backend service and waits for it to
   come back, reporting failure with the previous state intact rather than
   leaving the operator guessing which egress is live.
4. A saved egress that no longer exists falls back to the default with a
   warning at service start. Never fail to start over it.
5. Listing shows the notes from the inventory's comments, so the operator can
   tell egresses apart without decrypting anything by hand. Never print
   credentials.
6. Add zsh completion for egress names from the same source.

## Constraints

- No Clash controller and no local control port. Switching is a restart.
- Serialize concurrent invocations so the saved choice and the running
  configuration cannot disagree.
- The VPN command and capture are untouched. Confirm capture still reads the
  backend's resolver configuration after a switch, since it copies resolver
  addresses from the generated file.

## Acceptance

- [ ] `use` switches TCP, UDP and DNS together; existing flows are interrupted
      and recover on the new egress.
- [ ] The choice survives a reboot; `default` clears it.
- [ ] An unknown name is rejected without disturbing the running egress.
- [ ] A saved egress removed from the inventory starts on the default and says
      so.
- [ ] Vesktop and AyuGram keep working across a switch, reconnecting on the
      new egress.
