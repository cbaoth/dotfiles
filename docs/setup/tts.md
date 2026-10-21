---
title: Text-to-speech (read selection aloud)
hosts: [motoko]
status: resolved
tags: [tts, piper, sway, accessibility, voxtral]
updated: 2026-10-21
---

# Text-to-speech: read the selection aloud

**Manual (no `setup/` module yet):** Piper lives in the shared `~/.venv`
(`piper-tts` 1.8.0) and the voices are downloaded by hand into
`~/.cache/piper-tts/`. A module makes sense once the engine choice settles
(see *Next* below).

**Use:** select text anywhere, press **AltGr-F9** (sway). Press again to stop.
Selecting is enough (primary selection; clipboard is the fallback).

## Parts

| Piece | Role |
| ----- | ---- |
| `bin/tts-clean` | Engine-independent text cleaner: footnotes, URLs, markdown, dotted abbreviations (`S.M.A.R.T.` -> "Smart", `z.B.` -> "zum Beispiel"), line-wrap repair, sentence chunking, de/en detection |
| `bin/tts-speak` | Selection/stdin/args -> clean -> engine -> `pw-play`. Playback starts while later chunks are still being synthesized. `toggle` / `stop` / `list`, `-o file` to save |
| `~/.config/tts/tts-speak.conf` | Engine, speed, voice per language (shipped as `home/.config/tts/`) |
| sway binding | `40-keybindings.conf`, `bindsym --no-repeat $altgr+F9 exec tts-speak toggle` |

## Playback, pause, rewind

Audio is **streamed in chunks** (a few sentences each, the first one short):
the engine writes one wav per chunk and playback starts as soon as the first
is ready; it is never one big clip. mpv is the player, started idle, with each
finished chunk appended to its playlist over its JSON IPC socket (`socat`), so
mpv's own controls (your `~/.config/mpv/input.conf`: pause, seek, loop, speed)
all work, and `<` / `>` move between chunks.

`tts-speak` overrides a few settings of the personal mpv config: a looping
playlist (`loop-playlist=inf`) would never end, so the worker would never exit;
looping can still be toggled in the player. The first chunk gets 250 ms of
leading silence (`TTS_PAD_MS`): the audio device wakes up late and otherwise
swallows the first syllable. Saved files (`-o`) are padded at both ends.

The UI follows where it runs:

- **From a terminal:** stays in the foreground with mpv's terminal UI; status
  line `[chunk/total] time`; Ctrl-C quits.
- **From the hotkey:** a small mpv window, `--wayland-app-id=tts-speak`. Sway
  places it top-right like the tray apps (`$poptray, $stick`) and does not
  focus it (`no_focus`), so it does not cover or steal the text being read.
  The general mpv window rule does not apply to it.
- `-u none` is plain background playback without controls; `-o FILE` renders
  to a file for any player.

**Keys (sway):** the media keys and their alternatives (`$mod+Alt+Space`,
`Comma`, `Period`) control a running read-aloud first and fall through to
`playerctl` otherwise: `tts-speak pause|prev|next` fail when nothing is being
read. mpv has no MPRIS here, so playerctl cannot see it. `$mod+Alt+Backslash`
stops reading (`tts-speak stop`, which also quits the player).

## Comparing voices

`tts-compare` renders one text with many voices and plays the clips in one
mpv playlist. The status line shows the clip number and name; typing a number
jumps to that clip (`~/.config/tts/mpv-jump.lua`, loaded only here).

- **Default:** single-speaker Piper models of the language (`de_*` / `en_*`)
  plus the http server's voices for it, or the list in
  `~/.config/tts/voices.list`.
- **Multi-speaker models** are left out of that: they hold hundreds of voices,
  some of them other languages. Compare one on its own with
  `-m MODEL [--limit N]` (default 20 speakers, evenly spread; `0` = all).
  Clips are named `NN_piper_MODEL.SPEAKER.wav` (`.`, since `:` is not allowed
  on every filesystem).
- `--blind` shuffles and anonymizes the clips and shows the key afterwards.

Rendering the same text with several voices tells you whether a glitch belongs
to the voice, the model, the engine, or the text.

## Design decisions

- **Cleaning is separate from synthesis** because no TTS model reliably skips
  `[1]`, URLs or reads `S.M.A.R.T.` as a word. Every engine gets the same text.
- **An engine is a shell function** (`engine_NAME`) that turns a file of
  one-chunk-per-line into ordered `*.wav` files. Adding one is ~10 lines.
- **Heavy GPU engines do not live here.** They run as local servers in
  `~/git/cb-voice-lab` and are reached by the `http` engine
  (OpenAI-style `/v1/audio/speech`; URL in the conf). That keeps the dotfiles
  free of CUDA venvs, and lets puppet point at motoko instead of running
  anything itself.
- **Piper runs on CPU** (one process for all chunks, model load paid once).
  The `--cuda` warning seen earlier is harmless: only `onnxruntime` (CPU) is
  installed, and Piper is fast enough without a GPU (17 s of audio in ~2 s).
- **Worker is detached** via `setsid`, so its pid is its process group and
  `stop` is one signal. State is in `$XDG_RUNTIME_DIR/tts-speak/`.

## Voices

Defaults: `de_DE-thorsten-high`, `en_US-amy-medium`; `tts-speak list` shows
all installed. Piper voices: <https://huggingface.co/rhasspy/piper-voices>.

### Multi-speaker models

Models such as `en+de-libritts-multi-high` (265 speakers, renamed from
`multi_english-deutsch-libritts-high`) are used as `MODEL:SPEAKER`, e.g.
`tts-speak -v en+de-libritts-multi-high:thor`. SPEAKER is looked up by name in
the model's `speaker_id_map` first (here the names are mostly numbers: `161065`
is id 1), then taken as a raw id. An id out of range makes Piper write empty
wavs while exiting 0; `tts-speak` detects that and reports it. `tts-speak list`
marks multi-speaker models. Sources: <https://huggingface.co/rhasspy/piper-voices>
(e.g. `en_US-libritts-multi-high`, 904 speakers) and
<https://huggingface.co/fox3000foxy/piper-voices-collection>.

### Listening results (2026-10-21)

- **Voxtral** (http): clearly more natural than Piper, fewer TTS artifacts;
  numbers, ordinals and abbreviations read correctly ("am dritten Oktober
  zweitausendsechsundzwanzig"). English voices a little monotonous.
- **Piper German:** `de_DE-thorsten-high` best, `de_DE-audio_book-medium`
  close behind (a good narrator). All Piper voices stumble on numbers:
  "3." is read as "drei" with a sentence-end drop, and multi-digit numbers get
  short pauses inside the word ("fünf | unddreißig", "zweitausendsechs |
  undzwanzig"). `de_DE-kantodel` clips the first word and garbles some words.
- **`en+de-libritts-multi-high:thor`** is unusable for German: a pause after
  almost every word, strong English accent (the model phonemizes with
  `espeak.voice = en`). The model is a collection that also holds voices
  installed separately (Bender, Thorsten).
- Unnatural pauses in hard-wrapped text (Gutenberg) were a `tts-clean` bug,
  fixed: German nouns are capitalized, so case says nothing about a wrap.

## Next

- Piper number handling: spell out numbers and ordinals in `tts-clean`
  (German), if Piper stays in daily use. Voxtral does not need it.
- Try Chatterbox and Supertonic 3 (31 languages incl. German, upstream repo
  archived) behind the same http interface.
- Decide where Piper and its voices get installed from (module) once the
  engine choice is settled.
