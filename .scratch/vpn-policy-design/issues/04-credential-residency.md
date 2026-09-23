# Set the credential residency constraint

Type: wayfinder:grilling
Status: resolved
Blocked by: None

## Question

Concurrent egresses may require multiple credentials in running processes.
Must only the credentials for egresses currently in use be loaded, or is it
acceptable for the backend to hold the whole encrypted inventory after
runtime decryption? State how much implementation complexity is justified to
minimize residency while preserving the rule that credentials never enter Nix
evaluation, argv, the environment, logs, or the store.

## Answer

The one unprivileged sing-box backend may load every egress definition and
credential from the decrypted inventory at startup, including entries not
currently selected. Concurrent pins and `vpn --egress NAME` should not require
starting a separate credential-bearing backend. A manual named check can
reach a loaded egress without restarting pinned applications.

This accepts the in-process exposure because the same user already receives
the full decrypted inventory. Reducing credentials per process is not a hard
requirement and does not justify separate backend lifecycle and routing logic
by itself. Keep the existing hard boundary: credentials are parsed only at
runtime and never enter Nix evaluation, argv, the environment, logs, or the
Nix store. The privileged whole-host TUN stays credential-free.

Loading every egress does not authorize automatic selection or fallback. A
named pin must still fail closed. How the one backend routes concurrent entry
points and changes the temporary default remains the runtime-topology
decision.
