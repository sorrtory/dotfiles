# Vesktop on Ubuntu: Electron namespace permission

## Why this is needed

The staging VM enables `kernel.apparmor_restrict_unprivileged_userns=1`.
Its kernel audit log showed the Nix-installed Electron entering the restricted
`unprivileged_userns` profile and being denied `sys_admin` within that namespace.
Electron then tried its setuid sandbox helper, whose Nix-store permissions are
not suitable for that fallback, and aborted with the `chrome-sandbox` error.
This happens during an ordinary Vesktop launch, before any VPN capture.

## Selected workaround and security tradeoff

[The profile](../configs/apparmor/dotfiles-vesktop-electron) follows Ubuntu's
per-executable allowance pattern. It matches the exact resolved executable
used by the currently pinned Vesktop package, not its shell wrapper and not a
wildcard covering the Nix store. `flags=(unconfined)` with `userns,` permits
namespace use; it does **not** impose additional filesystem/network confinement.

This retains Electron's sandbox and leaves the global Ubuntu restriction on.
It grants no host-root identity and installs no setuid helper. However, allowing
user namespaces exposes additional kernel functionality to this executable,
which is exactly the attack surface Ubuntu's restriction reduces. Any other
application or code launched with this same Electron executable also receives
the allowance: the profile is executable-scoped, not Vesktop-code-scoped.

Do not substitute `--no-sandbox`, change permissions in `/nix/store`, or disable
the global restriction to make this error disappear. The profile is not a fix
for GPU, audio, login or VPN namespace problems.

## Explicit host setup

Normal Home Manager activation does not install this profile or invoke sudo.
On an AppArmor-enabled Ubuntu machine, after reviewing the exact executable
path and ensuring no conflicting profile already exists:

```bash
sudo apparmor_parser -Q -T configs/apparmor/dotfiles-vesktop-electron
sudo install -o root -g root -m 0644 \
  configs/apparmor/dotfiles-vesktop-electron \
  /etc/apparmor.d/dotfiles-vesktop-electron
sudo apparmor_parser -r /etc/apparmor.d/dotfiles-vesktop-electron
```

The first command checks the profile without loading it into the kernel. Run
from the repository root. Installation was authorized for staging only; this
document does not authorize applying it to the host. AppArmor loads the installed
profile on subsequent boots. Restart the application after a profile change.

## Upgrades and removal

The current attachment is the resolved Electron 43.1.0 executable used by
Vesktop `1.6.5-unstable-2026-07-16`. A package upgrade can change the store path.
Inspect the new executable chain, update the exact attachment in the repository,
and explicitly reinstall/reload the profile. Reverify sandboxing. Do not broaden
the attachment to all Electron versions or all of `/nix/store` to avoid this
maintenance step. Reproducible upgrade integration is follow-up host-setup work.

To remove the exception, first close applications using that Electron runtime,
then unload and delete only this profile:

```bash
sudo apparmor_parser -R /etc/apparmor.d/dotfiles-vesktop-electron
sudo rm -- /etc/apparmor.d/dotfiles-vesktop-electron
```

The source remains in the repository for recovery. Removing the exception makes
the original startup failure expected again while the global restriction is on.

## Verification

Compare the same startup probe before and after loading the profile, with core
dumps disabled. Confirm the global sysctl remains `1`, ordinary unprivileged
namespace probes remain restricted, and the running Electron sandbox processes
have distinct namespaces and seccomp filtering. A successful window alone does
not establish sandboxing or VPN capture. Keep account/session data private.

### Staging result — 2026-09-14

The before/after command was `ulimit -c 0; timeout 5
~/.nix-profile/bin/vesktop --version`. Before loading the profile it aborted with
the setuid-helper error; afterward it returned `Vesktop v1.6.5` with exit code 0.
The installed root-owned profile is mode 0644. The global restriction remained
`1`, and `unshare --user --map-root-user true` still failed with Operation not
permitted.

Vesktop was launched normally in the VM desktop using a temporary user unit
named `vesktop-sandbox-check.service`, without sandbox-disabling flags. The
processes carry the `dotfiles-vesktop-electron` AppArmor label. A sandboxed child
had distinct user/PID/network namespaces, zero effective capabilities,
`NoNewPrivs: 1`, and `Seccomp: 2` (filtering enabled). The browser/main process
is not expected to have the same restrictions as sandboxed children; this
observation is not a claim that every Electron process is equally confined.

The app was left running for the operator's account test. Quit it normally or
stop that test unit to close it; the temporary unit is not enabled at boot.
The installed AppArmor allowance persists. Host settings were untouched.

This initial test used ordinary networking, not the VPN wrapper. The Electron
exception does not allow arbitrary `unshare`. The subsequent combined test is
recorded below.

## Staging VPN-wrapped test

With operator approval, the VM also received the exact-path
[sing-box allowance](../configs/apparmor/dotfiles-sing-box). Install, validate,
reload, update and remove it using the same explicit procedure above, substituting
`dotfiles-sing-box` for the profile filename. It permits the pinned sing-box
binary to create its rootless capture namespace; it is not restricted to one
particular sing-box configuration. No allowance for Bash, nsenter, unshare or
all Nix executables was added. The global restriction remains enabled.

The staging generation was built with these evaluation overrides only:

```nix
dotfiles.localProxy.profile = "desktop-ubuntu";
dotfiles.appVpn.enable = true;
```

Its build output is `result-vpn-staging`. The repository's normal profile has
not enabled the provisional appVpn interface. Do not reactivate the default
laptop profile on staging while the host's legacy client uses that same peer.
The planned vpnizedApps module and normal desktop wrapping remain later work.

After confirming no direct Electron instance remained, Vesktop was launched
under the temporary `vesktop-vpn-test.service` through the installed VPN command.
The VM's normal network namespace was `net:[4026531833]`; capture and Vesktop's
main process shared `net:[4026532600]`. Electron's sandbox created additional
isolated child namespaces and retained seccomp filtering. Main application UID
was 1000 with zero effective capabilities and no-new-privileges enabled.

Discord HTTPS through the launcher returned 200; native STUN UDP through the
same active capture succeeded. These are network checks, not a completed voice
call. Account login and normal voice use remain the operator's test.

For this staging test, launch from the VM's desktop terminal with:

```bash
~/.nix-profile/bin/vpn ~/.nix-profile/bin/vesktop
```

The ordinary desktop icon and bare `vesktop` still launch directly. Fully quit
that direct instance before using the test command. The current generic
singleton check is not yet verified for Nix's Electron wrapper; the test start
explicitly checked that no old Electron instance was running.

To close the launched test and its app scope, quit Vesktop normally. Capture
stops when its last application scope exits; the shared proxy stays available.
The temporary test unit is not enabled at boot. No host activation or host
AppArmor changes were made.

References: [Ubuntu's per-application policy explanation](https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces),
[Chromium's alternatives and their tradeoffs](https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md).
