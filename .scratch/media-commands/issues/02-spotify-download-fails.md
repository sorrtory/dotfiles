# 02 — Diagnose Spotify download failure

Status: done
Priority: P1

## Evidence

On Fedora, the Spotify URL routes to `spotdl` but the download fails before
fetching the track. The traceback ends with a 30-second TLS timeout while
`spotdl` checks `music.youtube.com`:

```text
download mp3 https://open.spotify.com/track/4kXX1dTN3aw9JNznU9G3oU
...
ReadTimeout: HTTPSConnectionPool(host='music.youtube.com', port=443)
```

This may be a proxy propagation or spotDL/provider failure rather than Spotify
URL dispatch itself; the observed command must be reproduced with the local
proxy and with `PROXY=`.

## Work and acceptance

- Identify whether `download` passes the configured proxy correctly to spotDL
  and its provider requests.
- Make a normal Spotify track download succeed, or replace the traceback with
  a concise actionable error naming the failed provider and bypass option.
- Add a regression test at the command boundary; do not require network access
  in the test suite.

## Resolution

Two causes, both proxy propagation:

- spotapi, which spotDL 4.5 uses to read Spotify without API credentials,
  builds its TLS client with an empty proxy and ignores the environment. Direct,
  Spotify redirects to `why-not-available`, and spotapi fails with an
  `IndexError` parsing it. `modules/scripts.nix` patches it to fall back to the
  environment's HTTPS proxy.
- spotDL's `--proxy` covers only the audio download; ytmusicapi and spotapi read
  the environment. `download` now sets `HTTP(S)_PROXY` from `PROXY` for spotdl,
  so a run with no ambient proxy (a desktop launcher) still tunnels. The
  `music.youtube.com` timeout in the evidence is what a direct lookup gets.

`--use-official-api` is not a workaround: spotDL's shared client credentials
are rate-limited, so it needs a personal Spotify app's `--client-id` and
`--client-secret`. Some tracks, like the one above, resolve on Spotify but have
no YouTube match; that is a spotDL matching limit, not this issue.
