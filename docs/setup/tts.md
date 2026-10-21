---
title: Text-to-speech (read selection aloud)
hosts: [motoko]
status: resolved
tags: [tts, piper, sway, accessibility, voxtral]
updated: 2026-10-20
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
all of mpv's controls work and nothing is reinvented:

| Key | Action |
| --- | ------ |
| space | pause / resume |
| left / right | seek 5 s |
| `<` / `>` | previous / next chunk |
| `L` | loop the current chunk |
| `[` / `]` | slower / faster (pitch preserved) |
| `q` | quit |

The UI follows where it runs: from a terminal, `tts-speak` stays in the
foreground with mpv's terminal UI (Ctrl-C quits); from the sway hotkey there is
no terminal, so a small mpv window opens (`-u window`; sway's existing mpv
rules apply). `-u none` is the old plain background playback. For hotkeys
without focusing the window: `tts-speak pause`, `tts-speak prev` (restarts the
chunk, or goes to the previous one if it just started) and `tts-speak next`.
Use `-o FILE` to render to a file and play it with any player.

## Comparing voices

`tts-compare` renders one text with many voices (auto-discovered Piper models,
named speakers of multi-speaker models, and the http server's voices; or a
list in `~/.config/tts/voices.list`), prints render time per clip, and plays
them back to back in one mpv playlist (`>` next, `L` loop). `--blind` shuffles
and anonymizes the clips and shows the key afterwards. The same clip with
several voices tells you whether a glitch belongs to the voice, the model, the
engine, or the text.

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

Models such as `multi_english-deutsch-libritts-high` (265 speakers) are used as
`MODEL:SPEAKER`, e.g. `tts-speak -v multi_english-deutsch-libritts-high:thor`.
SPEAKER is looked up by name in the model's `speaker_id_map` first (here the
names are mostly numbers: `161065` is id 1), then taken as a raw id. An id out
of range makes Piper write empty wavs while exiting 0; `tts-speak` detects
that and reports it. `tts-speak list` marks multi-speaker models.

Caveat: that model's config has `espeak.voice = en`, so German text is
phonemized with English rules. Whether `:thor` sounds right for German needs a
listening test against plain `de_DE-thorsten-high`.

## Next

- Try Voxtral (already documented in `cb-voice-lab/docs/voxtral-tts`) behind
  an OpenAI-style server, then Chatterbox and Supertonic 3 (31 languages incl.
  German, but the upstream repo is archived). Judge on one German and one
  English paragraph.
- The `http` engine is written but untested against a real server.
- Decide where Piper and its voices get installed from (module) once the
  engine choice is settled.
