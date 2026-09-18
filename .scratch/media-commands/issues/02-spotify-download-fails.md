# 02 — Diagnose Spotify download failure

Status: needs-triage
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
