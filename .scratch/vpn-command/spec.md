# Spec: VPN command

Status: ready-for-agent

## Why

`docs/MIGRATION.md` §7. `docs/DECISIONS.md` parks this slice until the
WireGuard foundation exists, which it now does: `modules/secrets.nix` decrypts
`extra.conf`, and its own comment already states this command's purpose —
`extra` is "shared across machines and used to put a single application on the
other side rather than the host."

Today that is a 686-line legacy script at `~/Documents/scripts/vpn.sh`, outside
this repository, pointing at `/etc/wireguard/extra.conf`, a path the WireGuard
slice deliberately stopped using. The `vpn-up` and `vpn-down` aliases in
`modules/programs/zsh.nix` are a different thing entirely — they put the whole
host on a tunnel. This command puts one application there and leaves the host
alone.

## The behavior worth keeping

The legacy script's architecture is sound and the rewrite keeps it:

- A network namespace holding a WireGuard interface, so only processes placed
  inside it use the tunnel.
- The interface created on the host and moved in, because the tunnel's own
  encrypted packets must leave through the real network.
- A veth pair with NAT on the host, and a route pinned to the peer endpoint
  through it, so the tunnel does not try to route itself.
- A private mount namespace for the payload, so the namespace's resolver can be
  bind-mounted over `/etc/resolv.conf` for applications that read it directly.
- Dropping back to the invoking user before running anything.

## What changes

**DNS comes from the tunnel and never touches the host.** The legacy script has
three DNS modes, one of which repoints the host's `/etc/resolv.conf` and relies
on a backup to put it back. That is the one failure that outlives the command
and breaks the machine for everything else. The rewrite reads `DNS` from the
WireGuard configuration, falls back to a fixed resolver when the configuration
names none, writes only `/etc/netns/<ns>/resolv.conf`, and never modifies host
state that is not namespace-scoped.

**There is no GUI flag.** `-g` exists because the plain path does not work for
confined applications. Since a desktop application is the normal case, its
behavior becomes the only behavior: always a private mount namespace, always
the resolver overlay, always the desktop environment.

**The environment is inherited, not enumerated.** The legacy script names
sixteen variables and hardcodes fallbacks for six of them. Anything it forgets
is missing inside the namespace, and the fallbacks quietly lie when wrong. The
rewrite captures the invoking user's environment before escalating and restores
it after dropping back, so what runs inside sees what it would have seen
outside.

**It refuses to lie.** If the requested application is already running outside
the tunnel, the command stops and says so.

## The failure this exists to prevent

Electron and Chromium applications keep a `SingletonLock` and `SingletonSocket`
in their profile directory. Starting a second copy does not start a process: it
hands the request to the running one over that socket, which opens a window.
Run inside the namespace with a copy already running outside, the window
appears, the application works, and every byte it sends goes through the host's
normal connection. Nothing reports an error.

Snaps and Flatpaks have their own versions of this. `snap-confine` reuses a
per-snap mount namespace; Flatpak shares instances through its session
services. In each case, the observable result of "it worked" is identical to
the result of "it silently did nothing."

A tool whose purpose is to route one application through a tunnel cannot have a
silent mode where it does not. Detecting the case and refusing is therefore
part of the feature, not a nicety.

## Scope

In scope:

- `scripts/bin/vpn.sh`, packaged with `writeShellApplication` and exposed as
  `vpn` in the user environment.
- Namespace lifecycle: create, reuse, tear down, and tear down automatically
  when nothing is left inside.
- The payload running as the invoking user with a faithful environment.
- Refusing to run when an untunneled instance already exists.
- A test mode that reports the external address, and whether DNS can leak.
- Retiring the `vpn-up`/`vpn-down` aliases only if this command replaces what
  they do, which it does not today — they tunnel the host, this tunnels an
  application. See ticket 06.

Out of scope:

- Multiple simultaneous tunnels. This machine decrypts one shared `extra`
  configuration for this purpose; a second namespace has nothing to put in it.
- Transparent proxying of already-running processes. Moving a live process
  between network namespaces is not something Linux offers.
- The legacy script's `-r` resolved-uplink mode, which the spec above replaces,
  and its host `/etc/resolv.conf` rewriting, which it removes.
- Per-application proxying without a tunnel. That is §13, sing-box, and the
  boundary between the two is recorded there.

## Why not sing-box

The obvious question, since §13 brings in a userspace WireGuard endpoint
anyway: why keep a privileged namespace at all?

Because the two give different guarantees, and only one of them is a guarantee.

sing-box's local proxy is opt-in per connection. An application uses it when it
honors the proxy environment variables or has a proxy setting of its own, and
for Chromium-based applications `--proxy-server=socks5://127.0.0.1:1080` works
well. But opt-in means everything that does not opt in goes straight out: UDP
and QUIC, which Chromium prefers unless told otherwise; WebRTC; anything that
is not HTTP; and name resolution, unless the proxy is asked to resolve remotely
rather than the application resolving first. An application that ignores the
setting cannot be made to honor it. The failure mode is once again traffic
leaving untunneled while everything looks fine.

The network namespace is not opt-in. A process inside it has no route to
anything except the tunnel, whatever it thinks it is doing, whatever protocol
it speaks. That unconditional property is the entire reason to accept needing
root.

sing-box does have a mode that captures everything — a `tun` inbound with
`process_name` routing rules — but it wants `CAP_NET_ADMIN`, a TUN device, and
changes to the host's routing for *all* traffic in order to then exempt most of
it. That is a larger intervention in the host than a namespace that only
contains what is put in it, and it is precisely what §13 rules out.

So the boundary `docs/DECISIONS.md` already records stands, and this is the
reasoning behind it: sing-box is the convenient path for applications that
cooperate, this command is the guaranteed path for everything else and for
anything where being sure matters.

## Behavior baseline

1. Normal Home Manager activation must not invoke `sudo` (working rule 7).
   Only the command itself escalates, and only when run.
2. The payload runs as the invoking user, never as root.
3. The WireGuard private key must not reach a command line, an environment
   variable, a log, or the Nix store. The legacy script passes it through file
   descriptors; keep that.
4. Host state outside the namespace is restored on teardown, and nothing that
   is not namespace-scoped is modified in the first place.
5. Failure is loud. Every path that could leave an application untunneled ends
   in a non-zero exit and a message naming the cause.

## Definition of done

- `nix flake check`, the activation build, and `tests/*.sh` pass.
- `vpn curl https://ident.me` reports an address belonging to the tunnel, and
  the same command without `vpn` does not.
- An Electron application from `/usr/bin`, a snap, and a Flatpak each run
  through it with a working window, sound, and DNS, and each is verified to be
  in the namespace by comparing `/proc/<pid>/ns/net` against the namespace
  rather than by looking at the window.
- Starting one that is already running outside the tunnel fails with a message
  naming the running instance.
- After the last process exits, no namespace, veth, NAT rule, or resolver file
  remains.
- `docs/SOFTWARE.md` and `docs/MIGRATION.md` §7 describe what shipped.

## A note on verifying this

Every meaningful check needs root on a machine with a desktop session. The
staging VM has one, but privileged commands there have been refused by the
sandbox in past sessions, and the VM cannot render GPU-accelerated
applications. Expect part of the verification to need the operator's hands or
an explicit permission rule, and say so early rather than reporting an untested
command as finished.
