# 01 — sing-box as an unprivileged local proxy service

Status: resolved

## Goal

Establish one backend per machine, initially exposing the local proxy and
later shared with the namespace launcher. Follow the decisions in
`docs/DECISIONS.md` and [spec.md](../spec.md).

## Work

1. Reuse existing whole-file WireGuard ciphertext. Select an exclusive
   per-machine identity, defaulting to laptop here; do not migrate secrets again.
2. Add a Home Manager module with an explicit profile option, the package,
   a private SOPS runtime secret, and a systemd user service.
3. Package the separate Bash generator through `writeShellApplication`.
   Map the profile address, keys, endpoint, allowed IPs, optional MTU and DNS
   into the 1.13 WireGuard endpoint schema. Use keepalive 25; default MTU 1420
   and DNS 1.1.1.1. Accept one interface and one peer; reject hooks, duplicates,
   unknown fields, and invalid values rather than executing or guessing them.
   ListenPort and PersistentKeepalive are accepted source fields, but the
   userspace client uses an ephemeral port and the fixed keepalive policy.
4. Publish validated JSON atomically at mode 0600 inside a mode-0700 systemd
   runtime directory. Keep credentials out of arguments, environment, logs,
   and the Nix store. Do not print raw validator diagnostics.
5. Route both loopback listeners and destination DNS through the endpoint.
   Host DNS is only for resolving an endpoint hostname. No direct fallback.
6. Order after sops-nix; retry failed startup. Add an explicit ensure-only
   linger bootstrap phase. Removing this service must not disable linger
   needed by other user services.
7. Test valid/invalid profiles, defaults, failure redaction and atomicity.
   Ensure the bootstrap source fingerprint includes the new packaged source.

## Acceptance

- `nix flake check`, activation build, shell checks, and repository tests pass.
- On staging, SOCKS5h and HTTP on 1080 and HTTP on 3128 give tunnel egress.
- The runtime directory/config have modes 0700/0600.
- Restart recovers; stop removes listeners and runtime config.
- Routes, rules, interfaces and host resolver do not change.
- Proxy requests fail when stopped while direct requests work.
- Linger is enabled and the service starts before interactive login.
- Host activation and normal-use review remain operator-controlled.

## Follow-up

The namespace prototype establishes the version upgrade and capture behavior.
Client configuration and legacy retirement remain separate tickets.

## Answer

Implemented in `modules/programs/sing-box/`, with the private runtime
generator in `generate-config.sh` beside it and the explicit ensure-only
`08-user-linger` bootstrap phase. The Home Manager source fingerprint now
includes packaged scripts, covered by an isolated regression fixture.

Verification on 2026-09-11:

- ShellCheck, all 14 repository test scripts, `nix flake check`, and the
  activation build passed. The build did not read decrypted credentials.
- Normal staging dispatcher activation installed the service and enabled linger.
- All three listener URLs returned an egress different from direct requests,
  including after a 30-second idle interval.
- Runtime directory/config modes were 0700/0600.
- Restart recovered. Stop removed both listeners and the generated runtime
  directory. Hashes of routes, rules, interfaces and host resolver stayed equal
  through stop/start. Requests aimed at a stopped proxy failed; direct traffic
  still worked.
- After a staging reboot, the service was active 9.555 seconds into boot,
  before the verification SSH session began at 26.844 seconds. Linger was
  enabled, NRestarts was zero, and the proxy returned HTTP 200.

### Identity collision found during verification

The initial VM generation used the default laptop identity. Numeric IPv4 and
DNS-based requests intermittently stalled, then recovered together. Read-only
public-key fingerprint comparison proved that the running legacy ssProxy
container used that same identity. Stopped the VM service immediately; the
legacy container was not changed.

Retesting with the desktop-ubuntu identity used by the prior staging experiment
eliminated the reproduced stalls and passed the original probe, including an
idle interval. The VM's peer fingerprint differs from the legacy host peer.
This is the real integration regression case; a generator unit test cannot
reproduce contention with another machine's WireGuard connection.

The VM uses an evaluation override from the mirrored host source, not a guest
source edit:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
cd ~/Documents/dotfiles
nix build --impure --out-link result-singbox-staging --expr '
  let f = builtins.getFlake "path:/home/z/Documents/dotfiles";
  in (f.homeConfigurations.z.extendModules {
    modules = [ { dotfiles.localProxy.profile = "desktop-ubuntu"; } ];
  }).config.home.activationPackage
'
./result-singbox-staging/activate
```

Do not run the default Home Manager dispatcher on this VM while the legacy
host proxy is active: it would restore laptop and reintroduce the collision.
The host was built but not activated. Before host activation, the legacy
proxy must stop using laptop, or the new backend must select another exclusive
identity. No legacy files or services were removed or stopped.
