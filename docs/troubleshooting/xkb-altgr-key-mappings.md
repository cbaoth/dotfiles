---
title: AltGr key mappings in the custom Colemak layout (keyd, Super, VS Code)
hosts: [all]
status: resolved
tags: [keyboard, xkb, colemak, sway, keyd, vscode, zsh]
updated: 2026-08-15
---

# AltGr key mappings in the custom Colemak layout

**Verdict: resolved via xkb.** Arrow characters, `CapsLock -> Delete` and
`Delete -> Insert` all live on the AltGr layer in
`dotfiles/.config/xkb/symbols/custom`. Two approaches were tried and abandoned
first — **keyd** and **Super (Mod4) as a level shifter** — and one client
(VS Code) needs a per-app workaround even with the working approach.

No `setup/` module: the layout is a dotfile, deployed by `dotfiles-link` as a
symlink to `~/.config/xkb/symbols/custom`. There is nothing idempotent to
install. The VS Code keybindings are in Microsoft Settings Sync, not in this
repo — see [VS Code](#the-vs-code-trap) below.

## The trigger

On puppet, `Alt+.` in zsh (`insert-last-word`, bound in `.zshrc`) inserted a
stray character instead of the last argument. Same config worked on motoko.

Cause: a leftover `/etc/keyd/default.conf` on puppet from an abandoned
experiment, dated 2026-02-22:

```ini
[alt]
, = ←
. = →
```

keyd intercepts at the **evdev layer, below xkb and below sway**, so the key
never reached zsh at all. It had been silently eating `Alt+.` and `Alt+,` for
roughly six months. The character that actually appeared was not even the `→`
from the config — see the next section for why.

Diagnostic that found it: `swaymsg -t get_inputs` listed a
`keyd virtual keyboard` device that does not exist on motoko.

## Dead end 1: keyd

keyd was installed by hand (binary is `keyd.rvaiya`, never packaged into a
`setup/` module) to provide two things:

1. A `Super+/` **chord prefix** (`[meta_chord]` layer emitting `M-C-A-S-<key>`),
   to get more binding space in sway. **This never worked** — the sway config
   carried a `# FIXE dosen't work this way` comment for months.
2. Arrow characters on `Alt+,` / `Alt+.`, mirroring an AutoHotkey setup on
   Windows.

**Why keyd's Unicode output cannot work under sway:** keyd emits Unicode by
mapping the character onto a spare keycode in *its own virtual keyboard's*
keymap. But sway's `input "type:keyboard"` block matches the keyd virtual
keyboard too and overwrites that keymap with `custom(basic)`. The spare keycodes
are then reinterpreted through Colemak and emit an unrelated glyph. This is
structural: any sway config that sets `xkb_layout` for `type:keyboard` breaks
keyd Unicode.

Removed 2026-08-15:

```shell
sudo apt-get remove --purge keyd
sudo rm -rf /etc/keyd
```

The `docs/misc/keyd/` and `docs/misc/xremap/` config copies were deleted with
it; they are in git history at `93d3913`. The xremap config held a
Colemak/QWERTY per-application passthrough, superseded by `bin/kbd-layout-toggle`
plus the two `xkb_layout "custom,custom"` groups.

**Before retrying keyd:** only worth it for the chord prefix, on a compositor
that does *not* force its own keymap onto the remapper's virtual keyboard.
Under sway it is a dead end.

## What works: AltGr as LevelThree, level 4 only

`us(colemak)` already pulls in `level3(ralt_switch)`, so **AltGr is LevelThree**
with no `xkb_options` needed:

| Level | Modifier |
| ----- | -------- |
| 1 | plain |
| 2 | Shift |
| 3 | AltGr |
| 4 | AltGr+Shift |

The arrows went on **level 4 only**, so the level-3 dead keys survive. This is
free, and the reason is worth recording: `us(colemak)` puts `asciitilde` on
level 4 of **every key whose level 3 is a dead key** (13 keys) as pure filler,
and `~` already lives on Shift+grave. Those slots are unreachable duplicates.

```c
key <AB09> { [ period, greater, dead_abovedot,  U2192 ] };  // AltGr-Shift-.  ->  →
key <AB08> { [ comma,  less,    dead_cedilla,   U2190 ] };  // AltGr-Shift-,  ->  ←
key <AB07> { [ m,      M,       dead_macron,    U21D2 ] };  // AltGr-Shift-m  ->  ⇒
key <AB06> { [ k,      K,       dead_abovering, U21D0 ] };  // AltGr-Shift-k  ->  ⇐
key <CAPS> { [ BackSpace, BackSpace, Delete, Delete ] };    // AltGr-CapsLock ->  Delete
key <DELE> { [ Delete, Delete, Insert, Insert ] };          // AltGr-Delete   ->  Insert
```

Note `<AB06>` is `k` and `<AB07>` is `m` in Colemak — the bottom row is
`z x c v b k m , . /`. Easy to get backwards when copying key codes.

Only the `basic` (Colemak) variant is touched. The `qwerty` variant includes
`us(basic)`, which is a **2-level layout with no AltGr at all**; adding arrows
there would mean pulling in `level3(ralt_switch)` and stopping right-Alt from
being a plain Alt in the gaming sessions that variant exists for.

### Verifying a layout change without reloading sway

`xkbcli` is not installed; `xkbcomp` (from `x11-xkb-utils`) compiles offline:

```shell
cat > /tmp/test.xkb <<'EOF'
xkb_keymap {
    xkb_keycodes { include "evdev+aliases(qwerty)" };
    xkb_types    { include "complete" };
    xkb_compat   { include "complete" };
    xkb_symbols  { include "pc+custom(basic)+custom(qwerty):2" };
};
EOF
xkbcomp -I"$HOME/.config/xkb" -xkb /tmp/test.xkb -o /tmp/out.xkb
grep -A4 'key <CAPS>' /tmp/out.xkb
```

**Include both groups** (`custom(basic)+custom(qwerty):2`). Compiling only group
1 will miss interactions with the second layout group that sway actually loads.

Warnings about `Keycodes above 256` and `Key <I###> not found` are pre-existing
noise from `inet(evdev)` and unrelated to the layout.

## Dead end 2: Super (Mod4) as a level shifter

Windows binds `Delete` to `Super+CapsLock` via AutoHotkey (`#BackSpace::Delete`).
The obvious Linux equivalent **compiles, produces the correct keysym, and still
does not work**:

```c
// DOES NOT WORK — do not retry
key <CAPS> { type = "PC_SUPER_LEVEL2", [ BackSpace, Delete ] };
```

`PC_SUPER_LEVEL2` is a real type in `/usr/share/X11/xkb/types/pc`
(`modifiers = Mod4; map[Mod4] = Level2`), and `types/complete` includes it, so
no custom rules file or `xkb_file` is needed. `xkbcomp` confirms the keymap is
correct.

**Why it fails: toolkits never treat Mod4 as consumed.** `Super+X` must stay
available as a shortcut everywhere, so GTK/Qt/Electron deliberately do not mask
Super out of the modifier state. Clients therefore see `Super+Delete`, not
`Delete`. Observed symptoms, all from the same cause:

| Client | Behaviour |
| ------ | --------- |
| foot + zsh | Emits `\e[3;9~` (9 = Super). zsh reads the bare `\e` and drops into **vicmd** — block cursor. The rest is eaten as vi commands, and `~` is *toggle case*, so surrounding characters randomly changed case. |
| VS Code editor | Inserted a literal `0x7F`. `xkb_keysym_to_utf8(Delete)` **is** U+007F, so the keysym was right; VS Code just converted it to text instead of treating it as a key. |
| Firefox / Chrome | Nothing — unbound chord. |

No keymap change can fix this. A modifier that is not a level shifter cannot be
consumed. **Do not retry** unless the goal is a chord that clients should see as
a chord.

The only workaround would be a sway binding plus `wtype`
(`bindsym $mod+BackSpace exec wtype -k Delete`), where sway grabs the chord so
no modifier reaches the client. Rejected: an extra package and a second virtual
keyboard for one key, and it does not key-repeat on hold.

## The VS Code trap

Even with AltGr — the modifier that *is* correctly consumed — VS Code silently
drops mappings that produce a **named key** (`Insert`, `Delete`). Characters
(the arrows) are fine, because they go through the text-input path.

`Developer: Toggle Keyboard Shortcuts Troubleshooting` shows exactly why:

```
Received  keydown event - modifiers: [], code: Delete, keyCode: 45, key: Insert
Converted keydown event - modifiers: [], code: Delete, keyCode: 19 ('Insert')
Resolving ctrl+alt+[Insert]
No keybinding entries.
```

The raw event has **no modifiers** — Chromium consumed AltGr correctly and
delivered a clean `key: Insert`. But VS Code's keybinding service ignores the
event's modifiers and **re-derives them from the keyboard layout**: it sees that
this layout needs AltGr to produce `Insert`, encodes AltGr as `ctrl+alt` (a
Windows-ism applied on Linux too), looks up `ctrl+alt+Insert`, finds nothing,
and drops the key. It is not swallowing a chord — it is *inventing* one.

Fix, in `~/.config/Code/User/keybindings.json` (**Settings Sync, not this
repo** — so it propagates to motoko and Windows automatically):

```jsonc
{
    "key": "ctrl+alt+insert",
    "command": "editor.action.toggleOvertypeInsertMode",
    "when": "textInputFocus && !terminalFocus"
},
{   // the integrated terminal needs the bytes, not the command
    "key": "ctrl+alt+insert",
    "command": "workbench.action.terminal.sendSequence",
    "args": { "text": "\u001b[2~" },
    "when": "terminalFocus"
}
```

`AltGr+CapsLock -> Delete` presumably needs the same treatment
(`ctrl+alt+delete` -> `deleteRight`, and `\u001b[3~` for the terminal), but this
was **not confirmed in the log and not added** — `Ctrl+Alt+Del` is a chord that
might get pressed by hand, and binding it to `deleteRight` would silently eat a
character.

### Side finding: the old `capslock` VS Code hack

`keybindings.json` carried a long-standing `capslock -> replacePreviousChar`
entry, presumably from an era when Windows had no Colemak layout with the
CapsLock remap built in. On Linux it is **redundant**: with it commented out,
CapsLock does a real, selection-aware BackSpace, because VS Code resolves it
natively from the layout — the same layout-derivation that breaks the AltGr case
above.

Commented out rather than deleted (JSONC supports comments and syncs fine).
**Not yet tested on Windows**, which is the machine where it may still be
load-bearing.

## Where things live now

| What | Where |
| ---- | ----- |
| Layout (arrows, CapsLock, Delete) | `dotfiles/.config/xkb/symbols/custom`, deployed by `dotfiles-link` |
| Layout selection, two groups | `dotfiles/.config/sway/config`, `input "type:keyboard"` |
| Colemak/QWERTY toggle | `bin/kbd-layout-toggle`, bound to `Scroll_Lock` |
| VS Code compensation | `~/.config/Code/User/keybindings.json` — Settings Sync, **not** this repo |
| Windows counterpart | `~/git/AutoHotkey/Incl/KeyMap.ahk` |

Windows still binds Delete to `Super+CapsLock`; Linux uses `AltGr+CapsLock`.
The arrows are also unshifted on Windows but need AltGr+**Shift** on Linux.

## Quick diagnostics

```shell
swaymsg -t get_inputs                 # is a remapper daemon injecting a virtual keyboard?
cat -v                                # raw bytes a terminal receives; ^[[3~ = Delete
swaymsg reload                        # apply a layout change
```

In zsh, `\e[3;9~` (rather than `\e[3~`) means a modifier was **not** consumed —
the signature of the Super dead end above.
