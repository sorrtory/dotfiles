# 09 — Accept relative executable paths in vpn

Status: ready-for-agent
Priority: P2

## Evidence

At 1e75b0f, scripts/bin/vpn.sh uses command -v then requires an absolute path.
An existing executable supplied as ./program is rejected before networking;
relative PATH entries have the same problem.

## Work and acceptance

- Make the resolved executable absolute without dereferencing its final
  symlink: multicall argv[0] semantics must remain intact.
- Test ./program, ../program, a relative PATH entry, spaces and a symlink,
  alongside existing argument/PATH preservation and builtin rejection tests.
- Preserve unsupported package-family restrictions; relative spellings must
  not bypass path checks. No new runtime inputs in the user-facing wrapper
  that silently change the caller's PATH.
