---
title: Text-to-speech (read selection aloud)
hosts: [motoko]
status: resolved
tags: [tts, piper, sway, accessibility, voxtral, translation]
updated: 2026-11-08
---

# Text-to-speech: read the selection aloud

**Manual (no `setup/` module yet):** Piper lives in the shared `~/.venv`
(`piper-tts` 1.8.0) and the voices are downloaded by hand into
`~/.cache/piper-tts/`. A module makes sense once the engine choice settles
(see *Next* below).

**Use:** select text anywhere, press **Fn+F6** on the Logitech MX Mechanical (a Solaar rule, see [keyboard input](../reference/keyboard-input.md); other keyboards: bind `tts-speak toggle` in sway). Press again to stop.
Selecting is enough (primary selection; clipboard is the fallback).
**Fn+F7** (`tts-speak toggle --clipboard`) is the same with the clipboard first:
for the "copy as markdown" browser extension and the "Copy" buttons of AI chats,
which is how to get real Markdown out of a page. Browsers offer only plain text
on the primary selection, no `text/html` (checked 2026-11-08, Vivaldi and Firefox).

## Parts

| Piece | Role |
| ----- | ---- |
| `bin/tts-clean` | Engine-independent text cleaner, see *What the cleaner says* below: markdown, footnotes, reference sections, URLs, paths and other entities, dotted abbreviations (`S.M.A.R.T.` -> "Smart", `z.B.` -> "zum Beispiel"), numbers spelled out (de, en), line-wrap repair, sentence chunking, de/en detection. Golden tests: `tests/test_tts_clean.py` |
| `bin/tts-speak` | Selection/stdin/args -> clean -> engine -> `pw-play`. Playback starts while later chunks are still being synthesized. `toggle` / `stop` / `list`, `-o file` to save, `-k DIR` to keep sessions |
| `~/.config/tts/tts-speak.conf` | Engine, speed, voice per language (shipped as `home/.config/tts/`) |
| key binding | Solaar rules in `home/.config/solaar/rules.yaml` (Fn+F6, Fn+F7, motoko); no sway binding |

## What the cleaner says

Input is always parsed as Markdown (`markdown-it-py`, indented code off so plain
text with a margin survives). Everything else is rule-based; no LLM.

| Written | Spoken (en / de) |
| ------- | ---------------- |
| `https://www.example.org/a?b=1` | "web address example dot org" / "Web Adresse example Punkt org" |
| `ssh://git@host.example:22/x`, `ftp://…` | "SSH address host dot example", "FTP address …" |
| `[text](url)` | "text" |
| `example.org/docs` (no scheme) | as a URL, only for a short TLD list: `README.md`, `file.py` end in real TLDs |
| `jane.doe@example.org` | "jane dot doe at example dot org" |
| `/home/u/.config/app/config.ini` | "file config dot ini" / "Datei config Punkt ini" |
| `bin/tts-clean:42` | "file tts clean, line forty-two" |
| Code block | "Code block, Bash, three lines, skipped." / "Codeblock, S Q L, drei Zeilen, ausgelassen." |
| Inline code | read cleaned up; over 60 characters: "code skipped" |
| Table up to 6 rows, 4 columns | row by row: "Name foo, Value 1." |
| Larger table | "Table, 12 rows, skipped." |
| `[1]`, `[^1]`, `Plato¹`, `this.12 Then`, `[edit]`, note bodies | nothing |
| Trailing "References", "See also", "Einzelnachweise", "Weblinks", … | nothing (`tts-clean --keep-references` keeps them) |
| `+49 170 1234567` | digit by digit, in the written groups |
| `v1.2.3`, `Python 3.12`, `192.168.1.1` | "one dot two dot three", … |
| `2bd15e9`, UUID | "Hash", "UUID" |
| `MAX_RETRY_COUNT` | "max retry count" |
| `5 km`, `20 °C`, `3.5 GB/s` | full unit words |
| `x^2`, `mc²` | "x to the power of two" / "x hoch zwei" |
| `🚀 Launch`, `:rocket: Launch` | "rocket emoji, Launch" / "Rakete Emoji, Launch": a leading emoji acts as a bullet; a run is named once; names from the `emoji` package (CLDR) |

- **Spoken forms are held back** on private-use characters until abbreviation
  and number passes are done, so they cannot rewrite them (`Speaker`, `Held`).
- **Code block languages** are a table (`CODE_LANGUAGES`): aliases, spoken form,
  optional German one (SQL is "sequel" / "S Q L"). Unknown ones are read as written;
  add a row when one sounds wrong.
- **Reference sections** are only cut as a trailing run: walking back from the
  end, the first ordinary heading stops it, so "Notes" mid-text survives. Plain
  text has no headings, so a one-line paragraph counts only for unmistakable
  titles ("Einzelnachweise", not "Quellen").
- **Not handled (by choice, for now):** math (`$…$` is read as written), site
  specific URL rules ("the German Wikipedia article …"), any LLM step.
- `tts-clean` now has dependencies (PEP 723, `uv` provisions them on first run;
  about 0.08 s per call afterwards).

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
- **From the hotkey:** a small mpv window, `--wayland-app-id=tts-speak`,
  top-right below the bar, sticky and unfocused (`no_focus`), so it neither
  covers nor steals the text being read. Not `$poptray`: that runs
  `sway-place` on the *focused* window, which with `no_focus` is the window
  you were in (it moved the terminal, and the player stayed invisible at
  opacity 0). The rule maps it at opacity 0 and `tts-speak` itself calls
  `sway-place top-right --con-id ID --opacity 1`. A fullscreen window covers
  it, as it covers every floating window.
- `-u none` is plain background playback without controls; `-o FILE` renders
  to a file for any player.

## Keeping sessions (`-k DIR`)

Normally the chunks live in a tmpfs job dir (`$XDG_RUNTIME_DIR/tts-speak/job.*`)
and are deleted when the read-aloud ends; piper names them by
`monotonic_ns` timestamp. With `-k DIR` (or `TTS_KEEP_DIR` in the conf, which
then covers the hotkey too; `--no-keep` overrides it) the job renders straight
into a session dir on disk instead, and playback is unchanged:

```text
DIR/20261022-143012_piper-de_DE-thorsten-high_Erstes-Kapitel-Es-war-einmal/
  audio/0001.wav ...   chunks, renumbered in speaking order at the end
  playlist.m3u         relative paths: mpv DIR/.../playlist.m3u, or any player
  text.txt chunks.txt  the input as given, and as cleaned and chunked
  meta.json            engine, voice, lang, speed, ...; "regenerate" command;
                       chunks, files, complete; piper_opts, fixes
```

A stopped read-aloud keeps what was fully rendered (`complete: false`); the
newest file is dropped, since it may be half-written. Nothing is pruned: the
dir only grows (piper WAV is ~2.6 MB per minute). To make one file for a
phone: `ffmpeg -f concat -safe 0 -i <(sed "s|.*|file '$PWD/&'|" playlist.m3u) -c:a libopus -b:a 32k out.opus`
from inside the session dir.

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
  cb-voice-lab uses the same cleaner instead of a copy of its rules:
  `cb-qwen3-tts --text-filter tts-clean` pipes each text through it, and
  `--filter-ref-text` does the same for the clone reference transcript. The
  Piper fixes below are not meant for it: Qwen3 would read `[[phonemes]]`
  out literally.
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
- **Long sentences are split** (`TTS_SENTENCE_CHARS=150`, `tts-clean
  --sentence`). Piper speaks one sentence (up to `.!?`; `;` and `:` do not
  end one) in a single pass, and past ~13 s of speech it stops getting longer
  and crams the rest in: rushed, slurred, odd pauses. Measured with
  thorsten-high (2026-10-22), one sentence of growing length:

  | chars   | 70   | 131  | 174  | 231  | 274  | 345  | 382  |
  | ------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
  | s       | 3.7  | 7.1  | 9.2  | 12.4 | 13.0 | 13.6 | 13.9 |
  | chars/s | 18.9 | 18.6 | 19.0 | 18.6 | 21.1 | 25.3 | 27.4 |

  So an over-long sentence is cut at `; : –` (else a comma) and each piece
  gets its own line, i.e. its own pass. The Karamasow opening (a 283-char
  sentence at 26 chars/s, partly unintelligible) now renders at 17–20.
- **Mispronunciations are fixed per engine, not in `tts-clean`.** Piper
  phonemizes with espeak-ng, which gets some German words wrong (`vergeuden`
  as "ver-ge-uden", `-ium` with a long i and a stressed "um"); the voice
  says exactly what it is given. `~/.config/tts/piper-LANG.sed` (shipped:
  `home/.config/tts/piper-de.sed`) runs over the chunks before Piper only:
  a respelling (`geud` -> `gäud`) or `[[phonemes]]`, which Piper reads
  verbatim. The http engines have their own front-ends and never see it.
- **Names go in a per-book list, not the global one.** `--fixes NAME` adds
  `~/.config/tts/fixes/NAME.sed` (or any file; repeatable) after the
  language's fixes; a kept session stores a copy. Example:
  `fixes/die-brueder-karamasow.sed`. espeak-ng reads Russian names by
  German rules ("Fjodor" as "Eff-jodor", "Dmitri" as "De-mitri") and mostly
  stresses the wrong syllable; a name recurs hundreds of times in a novel,
  a one-off word does not, so only names and systematic errors are worth an
  entry. A one-off oddity ("wodu-urch" once, fine the next time) has
  identical phonemes both times: that is the model's timing noise
  (`noise_w`), not something a list can fix.
- **`[[phonemes]]` quirks** (piper 1.x, `voice.py`), handled by tts-speak
  after all fixes scripts: punctuation right after a block is dropped and the
  following word is glued on (`Mitja. Fjord` -> one word), so punctuation is
  moved into the block (it is a phoneme too) and a space kept. Piper also
  glues the next sentence onto a block's sentence, so a block that ends a
  sentence ends the line, i.e. one more wav file than chunks.
- **Tuning: `-p KEY=VAL,...` / `TTS_PIPER_OPTS`**, the model's own
  `.onnx.json` "inference" names: `noise_scale`, `noise_w`, `length_scale`,
  plus `sentence_silence`. Unset keys keep the model's defaults. `-s` divides
  the `length_scale` instead of replacing it; before that, a `length_scale`
  edited in the `.onnx.json` had no effect, since tts-speak always passed
  `--length-scale 1/speed`. Piper reads the `.onnx.json` on every start;
  nothing is cached. `noise_w=0.1` vs. `0.8` made one phrase ~8 % shorter
  and steadier: audible, but subtle.
- **Speed: prefer the player's.** `-s` changes the synthesis (Piper's
  `length_scale`) and did not fix the long-sentence rush. mpv's speed
  (`[` `]`, or `TTS_MPV_ARGS=(--speed=1.5)`) time-stretches at constant
  pitch, can change mid-read, and leaves kept sessions at normal speed.

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
- Fixed since: `tts-clean` spells out German numbers for every engine
  (`--no-numbers` to keep digits): cardinals, ordinals by context ("am 3." ->
  "am dritten", "der 1." -> "der erste", "3. Oktober" -> "dritter Oktober",
  a bare "Kapitel 3." stays a sentence end), dates, times, decimals, percent,
  thousands separators, years 1100-1999 as "neunzehnhundert...". Model names
  ("RTX 4070") and leading-zero codes are left alone.
- English numbers too (2026-10-28), American style without "and": amounts
  (`$156` -> "one hundred fifty-six dollars", `$1.50`, `$2 million`, `156 €`),
  ordinals (`21st`), decades (`1990s`, `'80s`), years in pairs ("nineteen
  eighty-four", "twenty twenty-six"; 2000-2009 "two thousand five"), times
  ("three thirty P M", "twelve o'clock"), decimals, percent, `1,500`. Version
  strings (`1.2.3`) are left alone. A bare 4-digit number from 1100 to 2099 is
  read as a year ("1500 meters" -> "fifteen hundred meters"); with a comma
  (`1,500`) it is a cardinal.
- Unnatural pauses in hard-wrapped text (Gutenberg) were a `tts-clean` bug,
  fixed: German nouns are capitalized, so case says nothing about a wrap.

## Translation (`translate`, `tlde` / `tlen`)

`bin/translate` translates locally with **TranslateGemma 4B** (Google, Gemma 3
fine-tuned for translation, 55 languages) in the system **Ollama** service:
English ↔ German by default, other pairs with `-s`/`-t`.

**Setup (once, ~2.5 GB):**

```sh
ollama pull hf.co/bullerwins/translategemma-4b-it-GGUF:Q4_K_M
```

**Use:**

```sh
translate -t de "The quick brown fox jumps over the lazy dog."
cat chapter1.txt | translate -t de > chapter1.de.txt
while-read translate -t de "<<<{}" \| tts-speak -l de   # translate and read each line
tlde This has * in it          # zsh front-end: noglob, * needs no escaping
tlen -- it's `raw`, ... too    # like qn: everything after ' -- ' literal (no global aliases)
tlde                           # multi-line prompt
```

Text comes from the arguments, stdin, or the selection (like `tts-speak`).
Paragraphs are translated one at a time and printed as soon as they are done,
so a pipe starts early; one line in gives one line out.

**Why it does not fight the TTS models for VRAM:**

- The model lives in Ollama, not in `translate`. Each call is one HTTP
  request, and `keep_alive` (default 30 min) keeps the model loaded, so a
  `while-read` loop pays no load per line.
- It runs on the **CPU by default** (`num_gpu: 0`; plenty of RAM, Ryzen
  9950X3D). The vLLM backends of `cb-tts-server` reserve their VRAM up front
  and take ~50 s to reload; a translator on the GPU could push them out or
  keep Voxtral from starting.
  - `--gpu` / `TRANSLATE_DEVICE=gpu` lets Ollama put as many layers as fit on
    the GPU. Only worth it when the GPU is free: next to a loaded TTS model the
    model is split between CPU and GPU, slower than the CPU alone, and the GPU is
    nearly full.
- A cb-voice-lab tool with `--free-gpu all` unloads Ollama models too. That
  only costs the translator a reload of a few seconds.

Measured (2026-11-03, 4B Q4_K_M, `cb-tts-server` holding Qwen3-TTS):

| Case | Time |
| ---- | ---- |
| one sentence, CPU, model loaded | 0.4–1.2 s |
| one sentence, CPU, cold (load from disk cache) | ~2 s |
| ~1900-char paragraph (2 chunks), CPU | ~23 s |
| `while-read translate -t de "<<<{}" \| tts-speak -e http -l de -o out.wav`, 3 short lines | ~3 s in total; the server's model stayed loaded |
| one sentence, `--gpu` (split 32 % CPU / 68 % GPU, 11.4 of 12 GB VRAM used) | 20 s cold, 8 s warm |

Settings are environment variables (`translate -h`): `TRANSLATE_TARGET`,
`TRANSLATE_MODEL` (e.g. the 12B for better quality, slower on the CPU),
`TRANSLATE_DEVICE`, `TRANSLATE_KEEP_ALIVE`, `OLLAMA_HOST`.

**Model choice:**

- HY-MT1.5 (Tencent, 1.8B/7B) is good and smaller, but its license excludes
  the EU.
- Opus-MT / Argos (CTranslate2) are tiny and fast on the CPU, but weaker on
  literary text.

**cb-qwen3-tts** translates through its text filter, no extra code:
`cb-qwen3-tts ... --text-filter 'translate -t de'`. Never add
`--filter-ref-text` there: the reference transcript has to match the reference
audio.

## Next

- Try Chatterbox and Supertonic 3 (31 languages incl. German, upstream repo
  archived) behind the same http interface.
- Decide where Piper and its voices get installed from (module) once the
  engine choice is settled.
