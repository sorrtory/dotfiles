# Spec: media download and conversion commands

Status: ready-for-agent

## Interface revision (2026-09-24)

The original type-first `download` interface below is historical. The operator
replaced it with `download [--as TYPE|EXTENSION] [--using BACKEND] URL...
[-- BACKEND_OPTIONS...]`. The URL chooses a backend and default result;
`--as` requests a result that backend supports, and `--using` overrides the
guess. Known video, audio, gallery, Google Drive, Yandex.Disk and direct-file
URLs dispatch without interaction. Unknown sites open an fzf backend picker on
a terminal and require `--using` in scripts. See `docs/DECISIONS.md` and
`scripts/bin/download.sh` for the current behavior. The old examples and
backend table below no longer specify the command-line interface.

## Problem

Downloading and converting media is currently spread across three places, none
of which is a command.

The legacy `~/.zshrc` carries `convert-to-mp3`, `convert-to-mp4` and
`mp3-to-mp4` as shell functions and `download-mp3` / `download-mp4` as aliases.
This session added `download-mp3`, `download-mp4` and `download-img` aliases to
the Zsh module and a `download-jpg` script, which is the same sprawl one layer
down.

Three consequences follow:

- An alias exists only in an interactive Zsh. None of this is reachable from a
  script, a desktop launcher, a keybinding, or a non-interactive `ssh`.
- Format knowledge is copied into each name. Adding `opus` means writing
  another alias with another proxy flag and another set of options.
- `convert-to-mp4` silently overwrites an existing `clip.mp4` when converting
  `clip.mkv`, and does so only after the transcode has finished. Work that
  cannot be recovered is destroyed by a command that looks like it only reads.

The tools themselves also disagree in ways that are invisible until something
breaks. `gallery-dl` has no image-format post-processor at all, so anything
producing JPEGs has to drive ImageMagick itself. `yt-dlp --proxy ""` means a
direct connection while `gallery-dl --proxy ""` silently falls back to the
environment. `--remux-video` fails outright rather than degrading when the
codecs do not fit the container. Each of these has to be known rather than
guessed, and today nothing records them.

## Solution

Two commands, and nothing else.

```
download <type|extension> [backend options] URL...
convert-to <extension> [ffmpeg or ImageMagick options] FILE...
```

`download` fetches. `convert-to` converts files already on disk. They never
call each other: when a downloader can produce the target format itself it is
always better at it, because it still holds the source streams, chapters and
metadata that a later re-encode has already thrown away.

The single argument does double duty. A **type** downloads in the source's own
format; an **extension** implies the type and asks for that format:

```
download audio URL     # best audio stream, untouched
download mp3   URL     # yt-dlp extracts and encodes
download video URL     # best video, untouched
download mp4   URL     # recoded to mp4
download image URL     # gallery-dl, exactly as published
download jpg   URL     # gallery-dl, everything still re-encoded to JPEG
download file  URL     # aria2c

convert-to mp3 *.m4a
convert-to mp4 clip.mkv
convert-to gif clip.mp4
convert-to jpg image.png
```

## User stories

1. As the operator, I want one command that downloads media, so that I do not
   have to remember which of five aliases wraps which tool.
2. As the operator, I want `download` to work in a script, a launcher and over
   `ssh`, so that automating a download does not mean rewriting the invocation
   by hand.
3. As the operator, I want to ask for a bare type, so that I can keep the
   source's own format when I do not want a re-encode.
4. As the operator, I want to ask for an extension, so that I get a file in
   that format without naming a tool or a flag.
5. As the operator, I want the command to pick the backend from what I asked
   for, so that I never have to know whether a site is a "gallery site".
6. As the operator, I want every backend option to still reach the backend, so
   that `--playlist-items`, `--range` and `--filter` keep working.
7. As the operator, I want downloads to go through the local proxy by default,
   so that I do not have to remember a proxy flag per tool.
8. As the operator, I want one way to bypass the proxy, so that I do not have
   to recall that yt-dlp wants `--proxy ""` and gallery-dl wants
   `-o proxy-env=false`.
9. As the operator, I want `--cookies-from-browser firefox` to work for both
   video and image downloads, so that an authenticated site works the same way
   in both.
10. As the operator, I want Spotify links to download with real album metadata,
    so that my library is tagged correctly.
11. As the operator, I want YouTube links to stay on yt-dlp by default, so that
    a lecture or a podcast is not mangled by a failed Spotify metadata match.
12. As the operator, I want to opt a YouTube link into Spotify tagging when I
    know it is music, so that I can get good tags for a track that is only on
    YouTube.
13. As the operator, I want my Spotify liked songs downloadable by name, so
    that I do not have to find a playlist URL for them.
14. As the operator, I want an mp4 that actually plays, so that I never get a
    failed remux because the source was VP9.
15. As the operator, I want a large plain file downloaded over several
    connections, so that an ISO or an archive does not take all evening.
16. As the operator, I want images downloaded exactly as published by default,
    so that nothing is re-encoded behind my back.
17. As the operator, I want to normalise a gallery to JPEG, so that a mixed bag
    of WebP and PNG becomes one format.
18. As the operator, I want JPEG sources left alone when normalising to PNG, so
    that I do not inflate photographs into larger files that recover nothing.
19. As the operator, I want videos and animations in a gallery left untouched
    by an image conversion, so that an animated GIF is not exploded into
    numbered frames.
20. As the operator, I want a failed conversion to keep its original, so that a
    bad re-encode costs me nothing.
21. As the operator, I want to convert files already on disk, so that I can fix
    a format without downloading anything again.
22. As the operator, I want an already-compatible video remuxed rather than
    re-encoded, so that a container change costs seconds and no quality.
23. As the operator, I want an audio file with cover art turned into a video,
    so that I can upload it where only video is accepted.
24. As the operator, I want to be told, not guessed at, when an audio file has
    no cover art, so that I do not get a black rectangle.
25. As the operator, I want a shareable GIF by default, so that the result is
    not a 50 MB file nobody can send.
26. As the operator, I want to override the GIF's size and frame rate, so that
    I can make a bigger one deliberately.
27. As the operator, I want to be told before any encoding starts that an
    output file already exists, so that I find out in the first second rather
    than twenty minutes in.
28. As the operator, I want a batch conversion to continue past one bad file,
    so that one broken input does not waste the rest of the run.
29. As the operator, I want a non-zero exit when anything failed, so that a
    script calling this can tell.
30. As the operator, I want `convert-to` never to delete my files unless I pass
    `-R`, so that the originals are still there when I dislike the result, and
    so that re-tagging or converting a library in place stays one command.
31. As the operator, I want a clear error when a format is impossible for the
    backend that has to serve it, so that I know to pick another.
32. As the operator, I want `--help` to tell me which types and extensions
    exist, so that I do not have to read the source.

## Settled design

### Dispatch

The type argument selects the backend. No URL is matched against a table of
sites: yt-dlp supports on the order of 1800 sites and gallery-dl hundreds, so
any such table is wrong the week it is written, and probing by trial costs a
network round trip per miss.

| `<type|ext>` | backend | conversion |
| --- | --- | --- |
| `audio` | yt-dlp `-x` | none, best source stream |
| `mp3 m4a opus flac wav aac alac vorbis ogg` | yt-dlp `-x` | `--audio-format` |
| `video` | yt-dlp | none, best source |
| `mp4 mkv webm mov` | yt-dlp | `--recode-video` |
| `image` | gallery-dl | none, exactly as published |
| `jpg png` | gallery-dl | ImageMagick through `--exec` |
| `file` | aria2c | none |

The only URL inspection is one `case` for Spotify. `gif` is deliberately absent:
it is a `convert-to` target only.

### Spotify

`open.spotify.com` URLs, `spotify:` URIs and the literal query `saved` always
route to spotdl, because nothing else can read them. Everything else defaults to
yt-dlp with no metadata matching. `--spotify-meta` opts a YouTube URL into
spotdl so that music gets Spotify tags.

This is the one flag `download` owns. It is justified where `-o` and a cookies
flag were not: passthrough can express any option a backend already has, but it
cannot select a different backend.

spotdl accepts `mp3 flac ogg opus m4a wav`. Requesting `aac`, `alac` or
`vorbis` from Spotify is an error naming what Spotify does support, rather than
a silent fallback to a worse-tagged file.

### Formats

The accepted vocabulary is the union across backends, translated where the
names differ. `ogg` is spelled `vorbis` by yt-dlp and `ogg` by spotdl, so
`download ogg` works for both. Where a backend genuinely cannot produce a
format the command fails with a message naming the alternatives.

`mp4` uses `--recode-video`, never `--remux-video`. yt-dlp's own help states
that if the target container does not support the codec, "remuxing will fail" —
it does not fall back, which is why remuxing a VP9/Opus stream into mp4 breaks.
`--recode-video` re-encodes only "if necessary", so a source that is already
mp4 costs nothing, and the existing `-S "res,ext:mp4:m4a"` sort makes that the
common case.

### Images

`download image` writes exactly what the site published. `jpg` and `png`
convert through gallery-dl's `--exec`, which runs a POSIX shell snippet per
downloaded file with the path substituted and shell-quoted. gallery-dl has no
image post-processor of its own — its post-processors are `classify`, `compare`,
`directory`, `exec`, `hash`, `metadata`, `mtime`, `python`, `rename`, `ugoira`
and `zip`, and `ugoira` is Pixiv-animation-to-video — so upstream's own
documented answer is to drive ImageMagick through `--exec`.

`jpg` converts `png webp bmp tif tiff avif jxl heic heif`. `png` converts only
`webp avif jxl heic heif` and deliberately skips JPEG: re-encoding lossy data
into a lossless container produces a larger file and recovers nothing.

Videos and animations are never converted. An animated GIF handed to
ImageMagick becomes `name-0.jpg`, `name-1.jpg` and so on, leaving the single
name the command promised absent.

### Deletion

`download` removes only files it created during that same run: the intermediate
that existed for the seconds between download and conversion, and only after a
conversion that both exited zero and wrote a non-empty file. A failure keeps the
original and warns.

`convert-to` never removes anything unless `-R`/`--replace` is given, which lets
each output take its input's place once it is written and non-empty.

### Output and options

Output goes to `$PWD`. `download` owns no destination flag, because each
backend already has one that passthrough reaches — yt-dlp `-P`, gallery-dl `-D`,
aria2c `-d` — and `-o` means four incompatible things across the four backends
and this command.

Everything after the type is passed to the backend verbatim, so the full tool
stays reachable and a typo produces the backend's own error.

Cookies need no flag either: yt-dlp and gallery-dl both spell it
`--cookies FILE` and `--cookies-from-browser BROWSER`, so passthrough already
gives one uniform spelling. spotdl (`--cookie-file`) and aria2c
(`--load-cookies`) are translated when those backends are selected.

### Proxy

`download` reads `$PROXY`, exported by the local-proxy module, and translates it
into each backend's own spelling: yt-dlp and gallery-dl and spotdl take
`--proxy`, aria2c takes `--all-proxy`. An empty `PROXY` means a direct
connection everywhere, so `PROXY= download mp4 URL` is the one bypass and it
cannot be spelled wrong.

This matters because the per-backend escapes disagree: `yt-dlp --proxy ""` is
documented as a direct connection, `aria2c --all-proxy ""` overrides a previous
proxy, but `gallery-dl --proxy ""` treats the empty value as unset and falls
back to the environment. Its real opt-out is `-o proxy-env=false`.

### convert-to

Targets are `mp3`, `mp4`, `gif`, `jpg` and `png`.

`mp4` probes with `ffprobe` and picks one of four recipes:

| input | recipe |
| --- | --- |
| already h264 + aac in another container | remux, no re-encode |
| any other video stream | transcode |
| audio with cover art | still image plus audio, as the legacy `mp3-to-mp4` did |
| audio with no cover art | error |

Remuxing is correct here and wrong in `download` for one reason: here the
codecs are read before anything is decided, where yt-dlp remuxes blind.

`mp3` keeps the source's cover art as the attached picture, copied rather than
re-encoded; a real video stream is not art and is dropped. The tag is ID3v2.3,
which more players read than the default v2.4.

`--cover PICTURE` applies to `mp3` and `mp4` only. For `mp3` it replaces any
existing art, and when the input is already mp3 the audio is copied, so adding
a picture costs no quality. JPEG and PNG are embedded as they are; anything
else is encoded to JPEG. For `mp4` it is the still image, which also makes audio
without art of its own convertible.

The still video is cut at the audio's measured length. `-shortest` alone let
x264's frame buffer run a 60 second song to a 117 second video. The picture is
also embedded as the mp4's cover (`covr`), in a separate copy-only pass, since
in the encoding pass a one-frame cover stream would end at once and cut the
output short. Thumbnailers, phones and media servers show that cover. An input that already has video is refused,
and so is a picture holding more than one frame: `-frames:v 1` cannot limit it,
because in FFmpeg 8 that ends the whole output, audio included, after one frame.

`gif` is two-pass `palettegen` / `paletteuse` at 15 fps scaled to 480px wide.
One-pass GIF encoding bands visibly, which is also why `download gif` does not
exist even though yt-dlp accepts `gif` as a recode target.

`jpg` and `png` convert still images already on disk through ImageMagick,
after the operator reported `convert-to jpg image.png` being refused (ticket
01). Unlike `download png`, an explicit JPEG to PNG is honoured: the file is the
operator's and they asked. Transparency is flattened onto white for `jpg`, EXIF
orientation is applied, and anything holding more than one frame — an animated
GIF or WebP, a multi-page TIFF, a video — is refused, because ImageMagick would
exit zero while writing `name-0.jpg`, `name-1.jpg` instead of the one output.

Every output path is checked before any encoding begins. If any target already
exists and is not its own input, the whole batch is refused and nothing is
converted; `--force` overrides. Nothing is ever removed implicitly. Once
encoding starts, a failure on one file is reported and the run continues, with a
summary at the end and a non-zero exit if anything failed.

### Surface

`download` and `convert-to` are the only commands. Every hyphenated name is
dropped: the `download-mp3`, `download-mp4` and `download-img` aliases added
earlier in this effort are removed from the Zsh module, and
`scripts/bin/download-jpg.sh` is deleted with its `--exec` converter moving
into `download`'s image branch. No aliases are introduced to replace them.

Both commands keep their Bash source under `scripts/bin/` and are packaged with
`writeShellApplication` in `modules/scripts.nix`, as `archive` and the existing
`download-jpg` already are.

## Testing decisions

A good test here asserts what the command does at its edge and nothing about how
it decides. Both commands are dispatchers, so their entire externally visible
behaviour is the command line they hand to an external binary, plus their exit
status and what they leave on disk.

There is one seam and it already exists: the process boundary, resolved through
`PATH`. Mock `yt-dlp`, `gallery-dl`, `aria2c`, `spotdl`, `ffprobe`, `ffmpeg` and
`magick` as scripts that record their argv, put them first on `PATH`, and assert
the recorded invocation. This is the seam `tests/bootstrap_*_test.sh` already
uses to mock `curl`, `sudo` and `apt-get`, and `tests/vesktop_launcher_test.sh`
to mock a launcher's payload. No new seam is introduced.

`tests/download_test.sh` covers: each type and extension reaching the right
backend with the right conversion flag; `ogg` translating to `vorbis` for
yt-dlp and staying `ogg` for spotdl; a Spotify URL and `saved` reaching spotdl
without the flag; a YouTube URL reaching yt-dlp without it and spotdl with it;
`aac` from Spotify failing with a message rather than running; `$PROXY`
appearing in each backend's own spelling; an empty `PROXY` producing no proxy
option anywhere; passthrough arguments surviving in order; `gif` being rejected
as a download type. It needs no network and no media.

`tests/convert_to_test.sh` covers the recipe choice, which is where the risk
lives, by mocking `ffprobe` with canned stream output: h264+aac choosing remux,
VP9 choosing transcode, audio with a video stream of one frame choosing the
cover-art path, audio without choosing the error. It also covers the pre-flight
refusal, that a refused batch leaves every file untouched, `--force`, and the
continue-on-error summary and exit status.

Where a real file is genuinely needed, the test generates it rather than
carrying a fixture: `ffmpeg -f lavfi -i testsrc` and `-f lavfi -i sine` produce
an 18 KB mp4 and a 9 KB mp3, and `magick -size 64x64 xc:red` a 316-byte PNG.
All are made in the test's temp directory, take under a second, and are
deterministic.

## Out of scope

- **lux, you-get, streamlink.** The operator does not use the Chinese sites lux
  exists for. Nothing here forecloses adding a backend later.
- **VK and vkvideo.** yt-dlp carries `vk`, `vk:uservideos`, `vk:wallpost`,
  `VKPlay` and `VKPlayLive` extractors, and the operator reports they do not
  work in practice. Diagnosing that is its own effort; cookies through
  passthrough may be all it needs.
- **GDownloader and omniget.** Both are GUI applications, not scriptable, and
  neither is packaged. GDownloader is notable only as independent confirmation:
  it is a GUI over yt-dlp, gallery-dl and spotDL, the same three chosen here.
- **HandBrake.** Its presets would replace one of four `convert-to mp4`
  branches, at a 1.4 GiB closure, and it cannot stream-copy video, which
  removes the remux branch entirely.
- **Av1an.** A chunked parallel AV1 encoder for slow archival work. AV1 in mp4
  has worse device compatibility than h264, which defeats the purpose of
  `convert-to mp4`.
- **ffmpeg-normalize.** Solves loudness, not format. A later `normalize-audio`
  command is a reasonable separate effort.
- **vips.** A faster ImageMagick replacement, but a one-line swap either way.
  Worth revisiting only if large images become slow.
- **`download gif`.** Covered above: one-pass GIF encoding bands.
- **Per-type output directories.** `download mp4` in a project directory must
  not silently write to `~/Videos`.

## Further notes

Every claim in this spec about tool behaviour was read from the tools
themselves at the versions this repository pins, not from memory: yt-dlp
2026.08.19 from `~/.local/bin`, gallery-dl 1.32.10 and aria2 1.37.0 and spotdl
4.5.2 from the `nixpkgs-unstable` input, ImageMagick 7.1.2-29 and FFmpeg from
the stable pin.

Two of them contradicted a recommendation made earlier in the same
conversation, which is why they are written down here rather than left as
knowledge: `--remux-video` fails instead of degrading, and `gallery-dl --proxy
""` does not mean a direct connection.

`gallery-dl` itself comes from the unstable pin because its extractors track
the sites they scrape; see `docs/DECISIONS.md`. `aria2` and `spotdl` are new
dependencies this effort introduces and follow the same reasoning as any other
package in `modules/packages.nix`.

The local-proxy module exports `$PROXY` from a single `proxyUrl` binding shared
with the wrapped-program launchers, so these commands and the `claude` and
`codex` wrappers cannot drift to different endpoints.
