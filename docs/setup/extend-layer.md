---
title: Extend layer (DreymaR) for XKB/sway — handover
hosts: [motoko, puppet]
status: open
tags: [keyboard, xkb, colemak, extend, sway, layers, autohotkey]
updated: 2026-10-23
---

# Extend layer — handover

Plan for bringing DreymaR's *Extend* layer (CapsLock held = navigation /
editing / media layer) to this setup. The Windows half already exists; this
note is the Linux half, written to be picked up and discussed on an actual
sway desktop (none of it has been tested — WSL has no `xkbcli` and no sway).

Upstream: <https://dreymar.colemak.org/layers-extend.html>

## Why this note exists

The reference implementation is [EPKL](https://github.com/DreymaR/BigBagKbdTrixPKL)
(Windows) and [BigBagKbdTrixXKB](https://github.com/DreymaR/BigBagKbdTrixXKB)
(Linux). On the work Windows machine, running EPKL is not an option — software
has to come from the IT kiosk, and a niche keyboard tool will not get onto the
company allow-list. AutoHotkey v2 *is* available there, so the Windows side was
reimplemented in the existing AHK repo instead.

On Linux there is no such constraint, but there is also no need for one: a full
Extend layer is **pure XKB data**, no daemon, no binary. It fits straight into
the existing `~/.config/xkb/symbols/custom` setup.

## Current state

| Platform | State |
| -------- | ----- |
| Windows (work) | **Done.** `~/git/AutoHotkey/Incl/Extend.ahk`, included from `AutoHotkey.ahk`. Syntax-validated, not yet lived with. |
| Linux (sway)   | **Not started.** This note. |

Relevant existing files here:

- `home/.config/xkb/symbols/custom` — variants `basic` (Colemak) and `qwerty`
- `home/.config/sway/config.d/10-output-input.conf` — `xkb_layout "custom,custom"`, `xkb_variant "basic,qwerty"`
- `bin/kbd-layout-toggle` — switches groups at runtime, also toggles `ctrl:nocaps`
- `docs/reference/keyboard-input.md`, `docs/troubleshooting/xkb-altgr-key-mappings.md`

## The layer

Extend1, positional. Letters are **Colemak** letters (what the key types here):

``` text
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|Esc   |F1    |F2    |F3    |F4    |F5    |F6    |F7    |F8    |F9    |F10   |F11   |F12   |
| Caps | Play | Prev | Next | Stop | Mute | Vol- | Vol+ | Media| Home | Srch | File | Calc |
+======+======+======+======+======+======+======+======+======+======+======+======+======+
|`     |1     |2     |3     |4     |5     |6     |7     |8     |9     |0     |-     |=     |
|      | F1   | F2   | F3   | F4   | F5   | F6   | F7   | F8   | F9   | F10  | F11  | F12  |
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|Tab   |Q     |W     |F     |P     |G     |J     |L     |U     |Y     |;     |[     |]     |
|      | Esc  | WhUp | BrBck| BrFwd| MsUp | PgUp | Home | Up   | End  | Del  | Esc  | Ins  |
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|Caps+ |A     |R     |S     |T     |D     |H     |N     |E     |I     |O     |'     |\     |
| EXT  | Alt  | WhDn | Shift| Ctrl | MsDn | PgDn | Left | Down | Right| Back | Menu | BrFav|
+------+------+------+------+------+------+------+------+------+------+------+------+------+
|      |Z     |X     |C     |V     |B     |K     |M     |,     |.     |/     |Spc   |Entr  |
|      | Undo | Cut  | Copy | Paste| MBt1 | MBt2 | MBt3 | MsLe | MsRi |      | Enter| PrtSc|
+------+------+------+------+------+------+------+------+------+------+------+------+------+
```

The point is not the arrows — it is the **home-row modifiers** `A`/`S`/`T` =
Alt/Shift/Ctrl, which chord with the rest of the layer:

- `Ext-T+N` → Ctrl-Left (previous word)
- `Ext-S+T+N` → Ctrl-Shift-Left (select previous word)
- `Ext-T+O` → Ctrl-Backspace (delete previous word)
- `Ext-A+4` → Alt-F4

## The CapsLock problem (decide this first)

`us(colemak)` gives CapsLock → BackSpace, and `custom(basic)` extends that with
AltGr+Caps → Delete. Extend wants the same key as its layer modifier.

**XKB has no tap-hold.** There is no way, in XKB alone, to get "tap = Backspace,
hold = Extend". Three ways out:

| Option | Trade-off |
| ------ | --------- |
| **A. Caps = Extend only** (DreymaR's own answer) | Backspace moves to `Ext-O` (QWERTY `;` position, right ring finger). Zero extra software. Both platforms behave identically if `EXT_TAP := ""` is set on the Windows side too. |
| **B. Caps = Extend, Backspace elsewhere** | e.g. keep a dedicated Backspace on the ISO key or on `Ext-O` *and* the physical Backspace. Same as A really, just a different crutch. |
| **C. `keyd` / `kanata` for tap-hold** | Gets tap=Backspace + hold=Extend, matching the AHK behaviour exactly. Costs a root daemon that grabs `/dev/input` — see the "grabbed devices" section of `docs/reference/keyboard-input.md`, it will show up there. |

Recommendation: start with **A**. It is the configuration DreymaR himself uses,
it is what the layer was designed around (`Ext-O` is deliberately a good
position), and it keeps Linux dependency-free. Revisit C only if `Ext-O` turns
out to be unbearable after a couple of weeks.

Note the asymmetry if A is chosen: `Incl/Extend.ahk` on Windows currently does
tap=Backspace. Set `EXT_TAP := ""` there to keep the muscle memory identical.

## Implementation

Stock `xkeyboard-config` already ships everything needed:

- `symbols/level5` → `level5(caps_switch)`: `key <CAPS> { [ ISO_Level5_Shift ], type[group1]="ONE_LEVEL" };`
- `types/level5` → `EIGHT_LEVEL`, `EIGHT_LEVEL_ALPHABETIC`, `…_WITH_LEVEL5_LOCK`

So levels 5–8 are reachable with a `caps_switch` include and `EIGHT_LEVEL` key
types. Levels 3/4 (AltGr, the dead keys and the arrow glyphs added in
`custom(basic)`) are untouched.

### Step 1 — vendor DreymaR's symbols file

Hand-rolling the full layer is possible but tedious (see the trap below), so
vendor the upstream data file. It is a keymap, not an executable:

``` shell
curl -L -o ~/dotfiles/home/.config/xkb/symbols/extend \
  https://raw.githubusercontent.com/DreymaR/BigBagKbdTrixXKB/main/xkb-data_xmod/xkb/symbols/extend
dotfiles-link   # ~/.config/xkb/symbols/extend
```

`libxkbcommon` searches `~/.config/xkb/` before the system paths, so
`include "extend(lv5)"` resolves to this file with no root involved and no
`install-dreymar-xmod.sh` run.

The file provides, among others:

| Variant | Contents |
| ------- | -------- |
| `extend(lv5)` | The main layer — everything except F# row and Backspace/Enter |
| `extend(lv5_fk)` | F# row (media keys). **Off by default upstream** because it eats `Ctrl+Alt+F#` TTY switching. |
| `extend(lv5_sk)` | Backspace/Enter mappings. Off by default, known to misbehave in some toolkits. |
| `extend(lv7)` | Second layer: numpad + nav block moved to the left hand (needs Caps+AltGr) |

### Step 2 — new variant in `custom`

Add a third variant rather than changing `basic`, so a bad day is one
`swaymsg reload` away from the old behaviour:

``` c
xkb_symbols "extend" {
    // Colemak, minus the CapsLock → BackSpace mapping: Caps is the layer key.
    include "us(colemak)"
    name[Group1] = "Colemak (US) + Extend";

    key <LSGT> { [ Hyper_L, Hyper_L ] };
    modifier_map Mod3 { <LSGT> };

    key <DELE> { [ Delete, Delete, Insert, Insert ] };
    key <AB09> { [ period, greater, dead_abovedot,  U2192 ] };
    key <AB08> { [ comma,  less,    dead_cedilla,   U2190 ] };
    key <AB07> { [ m,      M,       dead_macron,    U21D2 ] };
    key <AB06> { [ k,      K,       dead_abovering, U21D0 ] };

    include "level5(caps_switch)"   // CapsLock held = ISO_Level5_Shift
    include "extend(lv5)"
};
```

Open question: this duplicates most of `custom(basic)`. `include "custom(basic)"`
followed by an override of `<CAPS>` would be nicer — but `level5(caps_switch)`
sets `type[group1]="ONE_LEVEL"` on `<CAPS>` and XKB include merge order
(`override` vs `augment`) decides whether that wins over the four-level
BackSpace definition from `us(colemak)`. **Test it; if the include ordering
works, collapse the duplication.**

### Step 3 — sway

``` conf
input "type:keyboard" {
    xkb_layout  "custom,custom"
    xkb_variant "extend,qwerty"   # was: basic,qwerty
}
```

`bin/kbd-layout-toggle` and the comment block in
`config.d/10-output-input.conf` both still claim group 1 is `custom(basic)` with
Caps → Backspace — update both. Also check what the script's `ctrl:nocaps`
toggle does to a Caps that is now a level-5 switch; it very likely has to go.

## Known traps

1. **`modifier_map` is per-key, not per-level.** Putting `Alt_L` on level 5 of
   `<AC01>` does *not* give "Alt while Extend is held" — `modifier_map Mod1
   { Alt_L }` matches the *key*, so that key becomes Alt at every level and `a`
   stops typing `a`. The home-row modifiers need explicit actions:
   `actions[Group1] = [ …, SetMods(modifiers=Alt, clearmods=LevelFive) ]`.
   Upstream's file does this correctly — this is the main reason to vendor it
   rather than hand-roll.
2. **Levels 1–4 must be `Any`.** Upstream writes `symbols[Group1] = [ Any, Any,
   Any, Any, <keysym> ]` so the existing AltGr/dead-key levels from
   `custom(basic)` pass through. Do not replace them with concrete keysyms.
3. **Autorepeat is lost on keys that define actions** (XKB bug). Upstream adds
   `repeat=true` per key; if arrows still do not repeat, the fallback is
   `seq -s " r " 8 255 | xargs xset r` — which is X11-only and therefore useless
   under sway. Verify repeat behaviour early; it would be a deal-breaker.
4. **The lv5 modifier is not always eaten**, so some clients see
   `ISO_Level5_Shift` alongside the keysym. Upstream `clearmods` it per key.
5. **F# row vs TTY.** `extend(lv5_fk)` steals `Ctrl+Alt+F#`. Leave it out at
   first, or accept that VT switching needs `chvt`.
6. **Mod3 is already taken** by `Hyper_L` on `<LSGT>` for sway's `$hyper`
   bindings. `level5(caps_switch)` only assigns the `LevelFive` *virtual*
   modifier, so there should be no clash — but confirm with `wev` that
   `$hyper` bindings still fire.
7. **Group 2 (`qwerty`) is unaffected**, so the gaming/QWERTY toggle keeps a
   plain CapsLock. That is probably desirable; decide whether Extend should
   exist there too.

## Validation

``` shell
# compiles at all?
xkbcli compile-keymap --layout custom --variant extend > /dev/null

# what does the kernel/sway actually see?
input-keyboards debug          # evtest wrapper, docs/reference/keyboard-input.md
wev                            # keysyms as sway sees them

# effective keymap of the running compositor
swaymsg -t get_inputs | jq '.[] | select(.type=="keyboard") | .xkb_active_layout_name'
```

Smoke test, in order: `Caps+N/E/I/U` arrows → `Caps+T+N` word jump →
`Caps+S+T+N` word select → `Caps+O` backspace → `Caps+Z/X/C/V`.

## Windows counterpart (for reference / parity)

`~/git/AutoHotkey/Incl/Extend.ahk` — AHK v2, same positional map.

- CapsLock grabbed by scan code (`SC03A`) so it works whether the active Windows
  layout maps that key to CapsLock or to BackSpace.
- Tap/hold split: `EXT_TAP` (default `{BackSpace}`), `EXT_TAP_TIMEOUT` 250 ms.
- Home-row mods are genuine `{LAlt down}` / `{LShift down}` / `{LCtrl down}`
  presses, released when Caps is released; everything else is sent `{Blind}` so
  held modifiers pass through.
- Mouse keys `G/D/,/.` + buttons `B/K/M`, wheel on `W/R`.
- Not yet implemented there: Extend2 (numpad layer), tap-Extend dead-key layers,
  shifted media keys.

Known difference to settle once the Linux side exists: see the CapsLock section
above (`EXT_TAP`).

## Open questions

- Option A or C for CapsLock (see above)?
- Keep `basic` as group 1 during the trial and put `extend` in a third group, or
  swap `basic` → `extend` outright?
- Is Extend2 (`extend(lv7)`, numpad on Caps+AltGr) worth it, given the ScrollLock
  numpad layer that already exists in the AHK config and has no Linux equivalent?
- Should `bin/kbd-layout-toggle` grow an Extend on/off toggle, or is layout group
  switching enough?
