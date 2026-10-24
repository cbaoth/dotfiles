---
title: Extend layer (DreymaR) for XKB/sway
hosts: [motoko, puppet]
status: open
revisit: 2026-11
tags: [keyboard, xkb, colemak, extend, sway, layers, autohotkey]
updated: 2026-10-23
---

# Extend layer

DreymaR's *Extend* layer: hold CapsLock for a navigation / editing layer with
home-row modifiers. Implemented as pure XKB data, no daemon. On trial as the
default (first) layout group; `status: open` until it is decided whether it stays.

Upstream: <https://dreymar.colemak.org/layers-extend.html>

| Platform | Implementation |
| -------- | -------------- |
| Linux (sway) | `custom(extend)` in `home/.config/xkb/symbols/custom` + vendored `home/.config/xkb/symbols/extend` |
| Windows (work) | `~/git/AutoHotkey/Incl/Extend.ahk` (AHK v2; EPKL is not allowed there) |

## Usage

`Scroll_Lock` / `$mod+Insert` cycles the groups (`bin/kbd-layout-toggle`,
notification shows the active one):

1. `custom(extend)` — Colemak, **CapsLock held = Extend** (default)
2. `custom(basic)` — Colemak, CapsLock = Ctrl
3. `custom(qwerty)` — US QWERTY, CapsLock = Ctrl

All three: ISO key = Hyper (`$hyper`, Mod3), AltGr layer unchanged, NumLock
disabled.

## The layer

Extend1, positional. Letters are **Colemak** letters (what the key types here):

``` text
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|`     |1     |2     |3     |4     |5     |6     |7     |8     |9     |0     |-     |=     |
| (off)| F1   | F2   | F3   | F4   | F5   | F6   | F7   | F8   | F9   | F10  | F11  | F12  |
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|Tab   |Q     |W     |F     |P     |G     |J     |L     |U     |Y     |;     |[     |]     |
|      | Esc  | WhUp~| BrBck| BrFwd| MsUp~| PgUp | Home | Up   | End  | Del  | Esc  | Ins  |
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|Caps+ |A     |R     |S     |T     |D     |H     |N     |E     |I     |O     |'     |\     |
| EXT  | Alt  | WhDn~| Shift| Ctrl | MsDn~| PgDn | Left | Down | Right| Back | Menu | BrFav|
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|ISO   |Z     |X     |C     |V     |B     |K     |M     |,     |.     |/     |Spc   |
|Hyper | Undo*| Cut* | Copy*|Paste*| MBt1 | MBt2 | MBt3 | MsLe~| MsRi~|Compse| Enter|
+------+------+------+------+------+------+------+------+------+------+------+------+
* = keysym only, ~ = unusable (see Known limits).   Esc+Ext = CapsLock
Mouse keys (W R G D B K M , .) are unused; free for reassignment once the trial shows what is missing.
```

The point is the **home-row modifiers** `A`/`S`/`T` = Alt/Shift/Ctrl, which
chord with the rest of the layer, and Shift passes through:

- `Ext-T+N` → Ctrl-Left (previous word)
- `Ext-S+T+N` → Ctrl-Shift-Left (select previous word)
- `Ext-T+O` → Ctrl-Backspace (delete previous word)
- `Ext-A+4` → Alt-F4

## How it is built

`custom(extend)` = `custom(basic)` + `extend(lv5)`, then three local fixes.
`symbols/extend` is vendored **unmodified** (header names the upstream commit),
so it can be re-vendored; every adjustment lives in `custom`.

### Modifier budget: NumLock gave up Mod2

XKB has 8 real modifiers, and Extend needs one:

| Shift | Lock | Control | Mod1 | Mod2 | Mod3 | Mod4 | Mod5 |
| ----- | ---- | ------- | ---- | ---- | ---- | ---- | ---- |
| Shift | CapsLock | Ctrl | Alt | **LevelFive (Extend)** | Hyper | Super | LevelThree (AltGr) |

Stock `pc` puts LevelFive on **Mod3, next to Hyper**. That is not cosmetic:
sway matches bindings against the translated keysym *and* the unshifted one, so
Extend+E (Down) would also be seen as `Mod3+e` and fire `$hyper+e`. NumLock was
the cheapest thing to give up (no numpad in use), so `custom(mods)`:

- moves pc's fake `<LVL5>` key to `modifier_map Mod2`;
- voids `<NMLK>` — a NumLock still on Mod2 would *lock* Extend on;
- sway sets `xkb_options numpad:mac`, so a keypad types digits anyway.

libxkbcommon then gives NumLock its own pure-virtual bit (`NumLock=0x100`), so
nothing reaches Mod2 but Extend.

### CapsLock via explicit actions, not modifier maps

`modifier_map` is **per key, not per group**. `modifier_map Control { <CAPS> }`
would make Caps add Ctrl in the Extend group too. So Caps carries explicit
actions per group: `SetMods(modifiers=Control)` in `custom(mods)`,
`SetMods(modifiers=LevelFive)` in `custom(extend)`. This replaced the old
runtime `ctrl:nocaps` toggle (and the Caps → Backspace / AltGr+Caps → Delete
mappings, which never caught on).

### Shift-preserving key types

`extend(lv5)` uses `EIGHT_LEVEL_SEMIALPHABETIC`, which *consumes* Shift on
levels 5/6: Ext-S+T+N arrived as Ctrl+Left. `custom(extend)` re-types every
Extend key to `EIGHT_LEVEL[_ALPHABETIC]_WITH_LEVEL5_LOCK`, which has
`preserve[LevelFive+Shift] = Shift`. Their NumLock entries (NumLock as
level-5 lock) are inert because nothing can set NumLock any more.

### Hyper restored

`extend(lv5)` maps `<LSGT>` to Delete with explicit actions, which also kills
Hyper on levels 1–4. `custom(extend)` redefines it as Hyper.

### No auto-repeat on the home-row modifiers

Upstream sets `repeat=yes` on every key, including A/S/T. On Wayland the
*client* repeats a held key, and re-sends it with the modifier it set now
active: a held Extend+T arrived as Ctrl+t (zsh `transpose-chars`, VS Code
"Go to Symbol"). `custom(extend)` sets `repeat = no` on `<AC01>`, `<AC03>`,
`<AC04>`. Repeat is a per-key property, so holding `a`/`s`/`t` no longer
repeats the letter in **any** group — the price, judged acceptable.

### Extend+` disabled

`extend(lv5)` puts `Pointer_EnableKeys` (an X11 MouseKeys toggle, no use here)
on `` ` ``; `custom(extend)` voids levels 5–8 to keep the key free.

### Left out on purpose

- `extend(lv5_fk)` — media keys on F1–F12. Eats `Ctrl+Alt+F#` and collides with
  the `$altgr+F#` sway bindings.
- `extend(lv5_sk)` — Extend on Backspace/Enter; flaky in some toolkits.
- `extend(lv7)` — Extend2, numpad layer on Caps+AltGr. Only if Extend1 sticks.

## Known limits

1. **libxkbcommon ignores `Redirect`** (compile warning `XKB-362`): the app
   gets the *physical* key (Q, 1, Z) carrying the Extend keysym (Escape, F1,
   Undo). Everything that reads the keysym works; consequences:
   - Ext+Z/X/C/V send the `Undo`/`XF86Cut`/`XF86Copy`/`XF86Paste` keysyms, not
     Ctrl+Z/X/C/V. Cut/Copy/Paste work in GTK, Firefox and VS Code; Undo only
     in GTK; Shift+Ext+Z (`Redo`) nowhere by default.
   - **VS Code needs `"keyboard.dispatch": "keyCode"`.** The default `code`
     matches shortcuts by physical key, so Ext+Q did not close the command
     palette, Ext+1… did nothing, and T-then-S fired Ctrl+S. Undo/Redo are
     chords in `keybindings.json` (`capslock z`, `capslock shift+z`): VS Code
     has no Undo/Redo key names and sees CapsLock, then a bare Z.
2. **Mouse keys only half work.** Clicks (B/K/M) and single pointer steps
   (G/D/,/.) do work — what executes them on Wayland is unconfirmed — but
   pointer moves do not repeat (≈80 presses across a terminal window), and the
   wheel keys W/R act erratically (Firefox jumps to the end, VS Code pages).
   Not worth fixing; the keys are up for reassignment.
3. **X11 / XWayland apps get no Extend.** The X server cannot load
   `~/.config/xkb`; `kbd-layout-toggle` gives XWayland plain Colemak with
   `ctrl:nocaps` in the Extend group. Affects Wine/Proton games, not VS Code
   (native Wayland).
4. **No tap-hold.** XKB cannot do "tap Caps = X, hold = Extend". That needs
   `keyd`/`kanata` (root daemon on `/dev/input`); deliberately not used.
5. **Key recorders see CapsLock.** VS Code's "record keybinding" turns Extend
   combos into a `CapsLock …` chord; write the binding in the JSON instead.
6. **zsh has no bindings for Shift+arrows or F-keys**, so Ext+S+N prints `D`
   and Ext+5 a `~` — same as the real keys; not an Extend problem.
7. **Windows parity:** `Extend.ahk` still defaults to tap = Backspace. Set
   `EXT_TAP := ""` there for identical muscle memory.

## Validation

``` shell
# compile check with the library sway uses (libxkbcommon-tools, desktop profile)
xkbcli compile-keymap --layout custom,custom,custom \
  --variant extend,basic,qwerty --options numpad:mac --test

# compile from the repo, before dotfiles-link, with warnings
xkbcli compile-keymap --include home/.config/xkb --include-defaults \
  --layout custom,custom,custom --variant extend,basic,qwerty \
  --options numpad:mac --verbose 2>&1 >/dev/null | grep WARNING

wev                            # keysyms + modifiers as sway hands them out
swaymsg -t get_inputs | jq -r '[.[] | select(.type=="keyboard")][0].xkb_active_layout_name'
```

Smoke test in the Extend group, in order: `Caps+N/E/I/U` arrows → `Caps+T+N` word jump
→ `Caps+S+T+N` word select → `Caps+O` backspace → hold `Caps+E` (repeat) →
`ISO+w` still opens the browser → `Caps+E` must **not** open doublecmd.

## Open questions

- Keep `basic` and `extend` side by side, or retire `basic` after the trial?
- Extend2 (`extend(lv7)`) — only after Extend1 has stuck.
- Rearrange the dead keys (mouse, Z/X/C/V) to something useful on Wayland?
