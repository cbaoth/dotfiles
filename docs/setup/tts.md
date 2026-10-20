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

## Next

- Try Voxtral (already documented in `cb-voice-lab/docs/voxtral-tts`) behind
  an OpenAI-style server, then Chatterbox and Supertonic 3 (31 languages incl.
  German, but the upstream repo is archived). Judge on one German and one
  English paragraph.
- The `http` engine is written but untested against a real server.
- Decide where Piper and its voices get installed from (module) once the
  engine choice is settled.
