# 03: Isolate the shared VPN runtime

Status: ready-for-agent
Blocked by: 01 (AyuGram ownership), 02 (Vesktop and theme ownership)

**What to build:** Finish the behavior-preserving refactor so the shared VPN
module owns only `vpn`, namespace entry and on-demand capture. App modules use
its small launcher interface without owning capture service details.

- [ ] `vpn PROGRAM` still launches through the current namespace with TCP,
      UDP and DNS captured; a missing backend or capture does not put the
      payload on host networking.
- [ ] Concurrent launches still share one capture, and the last exit stops it;
      capture failure still stops bound payloads.
- [ ] Installed commands, service names, app entry points and enable options
      keep their existing behavior in this refactor.
- [ ] The reduced module has no Vesktop or AyuGram packaging or theme logic;
      staging observes the same app behavior before host approval.
