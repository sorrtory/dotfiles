# Spec: secret recovery UX on a fresh machine

Status: needs-triage

Found bootstrapping the staging VM from a snapshot (2026-09-15). Recovery
works; these are cost and interaction problems, deferred by the operator.

## Closure size

Phase 03 runs `nix run path:$REPO_ROOT#recover-age-identity` for a one-off
step. Its closure is 0.83 GiB, dominated by `keepassxc` (0.48 GiB, the full
Qt GUI build, used only for `keepassxc-cli`) and a second `git` (0.37 GiB)
although host-deps already guarantees host git. Evaluating the flake also
fetches its nixpkgs inputs. Everything stays in the store until garbage
collection, on the smallest disk the machine will ever have.

## GitHub sign-in prompt

`recover-age-identity.sh` asks "Open the sign-in page in a browser here?"
through `confirm`, which defaults to **no**. The no path sets
`BROWSER=true GH_BROWSER=true` so nothing opens, but `gh auth login --web`
still prints its "Press Enter to open github.com in your browser" prompt, waits
for Enter and echoes the no-op, so the operator's choice is not reflected.

A real bootstrap runs in the desktop session with a browser, so opening it
should be the default; the headless/remote path (staging over SSH) is the
exception.
