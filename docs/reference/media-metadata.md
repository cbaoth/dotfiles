---
title: Media metadata — what leaks, and how to strip it
hosts: [all]
status: resolved
tags: [exiftool, exif, xmp, privacy, photos, video, metadata]
updated: 2026-09-15
---

# Media metadata — what leaks, and how to strip it

Reference for [`bin/exif-sanitize`](../../bin/exif-sanitize). It records *why*
each topic maps to the tags it does, because most of these decisions are not
recoverable from the tag names alone.

## Use family-2 semantic groups, not tag lists

`exiftool -listd` lists deletable groups. The family-2 ones are *semantic*:

| Group | What it deletes |
| ----- | --------------- |
| `Location` | GPS plus textual location (IPTC City/Country, XMP, QuickTime) |
| `Author` | Artist, Creator, Copyright, By-line, OwnerName |
| `Camera` | make, model, lens, serials, shooting parameters |
| `Time` | every timestamp |
| `Document` | document/instance IDs, derivation links |
| `Preview` | embedded thumbnails and previews |

They are format-agnostic: one `-Location:all=` covers JPEG, RAW and QuickTime
alike, where a hand-written tag list has to enumerate each container and drifts
with every exiftool release.

Two family-2 groups are **not** usable as topics: `Image` is a catch-all holding
both technical data and `Software`, and `Other` is pseudo-tags (`FileName`,
`FileSize`).

## The three non-obvious leaks

**MakerNotes carry location and serials, and are undeletable piecemeal.**
Maker-note fields are flagged `Permanent`: `-Panasonic:City=` reports nothing to
do and the tag survives. Only `-MakerNotes:all=` clears the block. Measured on a
Panasonic DC-G9M2 JPEG: `-Location:all= -GPS:all=` removed the GPS tags but left
six Panasonic location fields intact. **A location strip that leaves MakerNotes
in place is not a location strip** — which is why `makernotes` is its own topic
and why `social` includes it.

The cost is low. `-MakerNotes:all=` took that file from 135 `Camera` tags to 25,
and everything a normal viewer shows survived: ExposureTime, FNumber, ISO,
FocalLength, LensModel, Make, Model, DateTimeOriginal, Orientation, ColorSpace,
dimensions. What goes is the proprietary blob.

**`SerialNumber` is a persistent cross-upload identifier.** It sits in ExifIFD,
outside MakerNotes, and survives a `Camera`-group delete on some files. It links
every photo you ever publish to one body. Hence the `serial` topic, separate
from `device` so make/model/lens can be kept without it.

**Embedded previews can predate a crop.** Not every editor regenerates the
thumbnail, so a cropped image can still ship a preview of the uncropped frame.
`-Preview:all=` plus the explicit `ThumbnailImage`/`PreviewImage`/`JpgFromRaw`
tags.

## `-all=` removes colour information

Stripping everything shifts colours unless the colour-space tags are restored:

```bash
exiftool -all= -tagsfromfile @ -ColorSpaceTags -Orientation file.jpg
```

exiftool deliberately leaves the JPEG APP14 `Adobe` segment alone (removing it
changes the appearance) but does remove the rest. `Orientation` must be copied
back too or the image displays rotated. This is the `anon` profile's path; it
leaves pixel data untouched (`ImageDataMD5` is unchanged).

## No `-if` guard is needed to avoid pointless writes

exiftool detects a write that produces no change, leaves the file alone, and
reports it as unchanged — verified by inode and mtime:

```console
$ exiftool -P -overwrite_original -efile2 unchanged.txt -Rating= clean.jpg
    0 image files updated
    1 image files unchanged
```

`-efile2` captures the unchanged list. So re-running a profile is cheap, and a
read-then-write pre-check would only add a pass.

## `touch -d` parses the space form as UTC

Relevant to [`bin/rename-timestamp-prefix --set-mtime`](../../bin/rename-timestamp-prefix).
EXIF timestamps are unzoned local wall-clock. With `/etc/localtime` at
Europe/Berlin:

```console
$ touch -d "2025-06-01 10:00:00" f   # -> 12:00:00 +0200   (parsed as UTC)
$ touch -d "2025-06-01T10:00:00" f   # -> 10:00:00 +0200   (parsed as local)
$ touch -t 202506011000.00       f   # -> 10:00:00 +0200   (parsed as local)
```

`date -d` parses *both* forms as local, so the two tools disagree. Always pass
the ISO `T` form to `touch`.

## exiftool emits tags in the order requested

Which makes a priority fallback chain a single call:

```bash
exiftool -s3 -d FMT -SubSecDateTimeOriginal -DateTimeOriginal -CreateDate \
         -Keys:CreationDate -MediaCreateDate -- file
```

Caveat: invalid dates (`0000:00:00 00:00:00`, common in transcoder output)
come back **unformatted**, with colons. Filtering for the formatted
`^[0-9]{4}-[0-9]{2}-[0-9]{2}T` shape drops them; taking the first non-empty line
does not, and yields a garbage timestamp.

## Video

`Keys:CreationDate` is what phone video actually carries — `DateTimeOriginal` is
usually absent, which is why a chain that only asks for it skips every video.
GPS in MP4/MOV lives in `ItemList:GPSCoordinates` and is reached by
`-Location:all=`.

### QuickTime dates are timezone-ambiguous; `Keys:CreationDate` is not

`QuickTime:CreateDate` is a bare datetime. The QuickTime spec defines it as
**UTC**, but most consumer devices write **local time** there instead, so the
value alone cannot tell you which convention it follows. exiftool defaults to
assuming local (the pragmatic read for consumer files); `-api QuickTimeUTC=1`
flips it.

`Keys:CreationDate` (`com.apple.quicktime.creationdate`) is an ISO 8601 string
*with* the offset, so it is unambiguous. Prefer it.

Why it matters — a clip shot in Japan at 21:19:25+09:00, read on a Berlin box:

| Tag | Stored | exiftool default | `QuickTimeUTC=1` |
| --- | ------ | ---------------- | ---------------- |
| `QuickTime:CreateDate` | `12:19:25` (UTC) | `12:19:25+0200` ✗ | `14:19:25+0200` |
| `Keys:CreationDate` | `21:19:25+09:00` | `21:19:25+0900` ✓ | `21:19:25+0900` ✓ |

The default reading of `QuickTime:CreateDate` is wrong twice over: 12:19 is
neither the capture wall-clock (21:19) nor the same instant in local time
(14:19) — it is the UTC value wearing a local label.

So the date chain in `bin/rename-timestamp-prefix` puts `Keys:CreationDate`
ahead of the bare `CreateDate`. The result is the **wall-clock at the place of
capture**, which is what `DateTimeOriginal` already means for stills, so photos
and video sort consistently.

Residual ambiguity: for video with no `Keys:CreationDate` (Android, GoPro,
ffmpeg output) only the bare QuickTime date exists and the convention is
genuinely unknowable from the file. exiftool's assume-local default is the
better bet for consumer devices; files that really do store UTC read an offset
early, and `-api QuickTimeUTC=1` corrects them.

### Partly-rewritten dates

Editors routinely update one date tag and not another. The documented Apple
case: trimming a video and saving it as a new clip sets a fresh
`QuickTime:CreateDate` but keeps the original `Keys:CreationDate`.

`rename-timestamp-prefix --warn-mismatch [HOURS]` (default 24) compares the
candidate tags as **instants** and skips a file whose sources disagree by more
than the threshold, rather than silently picking one.

Comparing instants rather than wall-clock strings is what makes the default
threshold work: a timezone disagreement is only the offset difference (the
Japan example above spreads exactly 7200s — 2h), while a genuinely rewritten
date is days out. So the default catches rewrites without firing on travel.

Treat it as a flag for review, not a classifier. A gap is evidence that
*something* touched the file, not proof of what; remuxing and metadata-repair
tools produce gaps on untouched files, and plenty of real edits produce none.
Deciding what a file *is* stays a human call.

## Not automated

This is a reference note: no machine state, so no `setup/` module. The only
dependency is `libimage-exiftool-perl` (a virtual-package trap — see
[package-managers.md](package-managers.md)), installed via
`setup/packages/desktop.list`.
