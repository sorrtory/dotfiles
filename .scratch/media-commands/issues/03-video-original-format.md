# 03 — Preserve the requested video format

Status: needs-triage
Priority: P2

## Evidence

`download video` was expected to keep the source video format, but yt-dlp
selected separate streams and merged them into a WebM container:

```text
[info] ... Downloading 1 format(s): 397+251
[Merger] Merging formats into "...webm"
```

The selected video stream was MP4 (`f397.mp4`) while the audio stream was WebM
(`f251.webm`). The current dispatcher describes `video` as “best video stream,
untouched”, but yt-dlp's best-video-plus-audio selection necessarily creates a
new container.

## Work and acceptance

- Decide whether `download video` means one untouched combined format, the best
  video stream regardless of container, or best quality with an explicit merge.
- Make the help text, format selection and resulting extension agree.
- Add a mocked regression test for a mixed-container video/audio selection and
  verify that an explicit `download mp4` path remains recoded as designed.
