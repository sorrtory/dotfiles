# 01 — Support image targets in convert-to

Status: resolved
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

## Answer

`convert-to jpg` and `convert-to png` are supported targets, driven by
ImageMagick. They share the existing preflight: outputs are worked out first,
collisions refuse the batch unless `--force`, two inputs cannot claim one
output, and originals are never removed. `jpg` flattens transparency onto white
and applies EXIF orientation. Anything holding more than one frame (animated
GIF/WebP, multi-page TIFF, video) is refused by frame count rather than split
into `name-0.jpg`, `name-1.jpg`. An explicit JPEG to PNG is honoured, unlike
`download png`, since the operator asked for it.

Fixed alongside: a relative path containing a colon, such as `Song: Live.mkv`,
was read by ffmpeg as a URL (`Protocol not found`) and by ImageMagick as a
format prefix. Paths now reach both tools as `./path`. ImageMagick's `%d`
expansion in output names is escaped as well.
