# 02 — Make the GitHub sign-in choice real, and browser-first

Status: needs-triage

## Problem

Answering no to "Open the sign-in page in a browser here?" still leaves `gh`
prompting "Press Enter to open github.com in your browser", waiting and
echoing, because `BROWSER=true` only neutralises the open. The prompt also
defaults to no, the right answer only for a remote session. See ../spec.md.

## Work

1. Default to opening the browser (`[Y/n]`), since a real bootstrap happens in
   the desktop session.
2. On the no path, show the device code and URL without `gh`'s own Enter
   prompt (check `gh auth login` flags and non-TTY behaviour for its version).
3. Keep the staging-over-SSH path working; update docs/STAGING.md if the
   answer it needs changes.
