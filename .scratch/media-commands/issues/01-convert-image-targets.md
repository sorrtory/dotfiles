# 01 — Support image targets in convert-to

Status: needs-triage
Priority: P2

## Evidence

On Fedora, converting an existing PNG with the image target requested by the
operator is rejected:

```text
convert-to jpg /home/z/Downloads/9ca1100f-f3e9-47f2-a871-fc2b4f15ddb7.png
convert-to: cannot convert to 'jpg'; supported targets are mp3, mp4 and gif
```

The current settled design assigns image normalization to `download jpg/png`
and limits `convert-to` to `mp3`, `mp4` and `gif`. The operator nevertheless
expects `convert-to jpg` to work on files already on disk, so this is both a
reported usability bug and a scope decision against the current spec.

## Work and acceptance

- Decide whether `convert-to jpg` and `convert-to png` become supported targets,
  or document and surface `download jpg/png` as the only supported interface.
- If added, preserve originals, handle batches and collisions like the existing
  targets, and test PNG/WebP/JPEG inputs plus animated images.
