# 01: Give AyuGram its own module

Status: ready-for-agent
Blocked by: None (can start immediately)

**What to build:** Keep AyuGram's VPN launch behavior intact while moving its
package replacement, D-Bus launcher and theme opt-in out of the shared VPNized
apps module. This is the first behavior-preserving part of the module split.

- [ ] The existing enable option still installs the same AyuGram command and
      desktop/D-Bus entry points, with calls captured by the current VPN.
- [ ] An already-running AyuGram still receives second launches safely; its
      login/session state remains machine-local.
- [ ] Telegram theme generation and registration still occur when AyuGram is
      enabled, without placing the theme implementation in VPN runtime code.
- [ ] A reviewed generation is checked on staging before any separately
      approved daily-host activation.
