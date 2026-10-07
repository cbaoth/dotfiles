---
title: Floating windows pile up in the centre after suspend/resume (sway)
hosts: [motoko]
status: resolved
tags: [sway, wayland, suspend, floating, output, swayidle, dpms]
updated: 2026-10-07
---

# Floating windows pile up in the centre after suspend/resume

**Verdict: workaround.** Sway destroys floating geometry whenever an output goes
away and comes back — which is what a suspend/resume does. Upstream closed this
as *not planned*, so it can only be fixed from outside sway.
`bin/sway-float-geometry` saves the geometry on `before-sleep` and puts it back
on `after-resume`, driven by the existing swayidle hooks. Since 2026-10-06 a
`watch` daemon does the same for *any* output loss, not only suspend — see
[Update 2026-10-06](#update-2026-10-06-output-loss-without-a-suspend).

No `setup/` module: the fix is a script in `bin/` plus a config fragment, both
deployed by `dotfiles-link`. Nothing idempotent to install.

## The symptom

Arrange floating windows deliberately, suspend, resume — and every floating
window is sitting in the middle of the screen at its default size, stacked on
top of the others. They have to be dragged apart by hand, every single time.

Worst on this config specifically, because a lot of windows are marked
sticky+floating via `$stick` / `$poptray` / `$poptray_sheer` in
`70-window-rules.conf`: KeePassXC, Nextcloud, pavucontrol, blueman, flameshot,
Safe Eyes, nm-applet, the calculators, sway-winfo. Sticky floaters take the
*unconditional* centring path (below), so all of them land on the same spot.

## Root cause

Read from `swaywm/sway` at tag 1.11. Three functions in `sway/tree/output.c`:

On resume the DRM connector is re-created, so sway tears the output down and
rebuilds it. Tearing down evacuates every workspace:

```c
// sway/tree/output.c:293 — output_disable()
list_del(root->outputs, index);
output->enabled = false;
output_evacuate(output);
```

`output_evacuate()` (`:203`) walks every workspace off the dying output and, when
no other real output claims it, parks it on `root->fallback_output` — the **NOOP
output, which is 0×0**.

Then on re-add, `output_add_workspace()` (`:70-81`) sanity-checks each floater
against the output box:

```c
if (floater->pending.width == 0 || floater->pending.height == 0 ||
        floater->pending.width > output->width ||
        floater->pending.height > output->height ||
        floater->pending.x > output->lx + output->width ||
        ...) {
    container_floating_resize_and_center(floater);
}
```

Coming from a 0×0 output, **every one of those tests trips**, so every floater is
resized to default and centred.

Sticky containers are worse — `evacuate_sticky()` (`:197`) does not test
anything at all:

```c
container_detach(sticky);
workspace_add_floating(new_ws, sticky);
container_handle_fullscreen_reparent(sticky);
container_floating_move_to_center(sticky);   // unconditional
```

Upstream: [swaywm/sway#7713](https://github.com/swaywm/sway/issues/7713)
("Floating windows loose their positions and size after waking up from lock
invoked by swayidle") — **closed as not planned**. Related:
[#6304](https://github.com/swaywm/sway/issues/6304).

## Dead ends

- **DPMS: ruled out from the C source, then proven wrong on this hardware
  (2026-10-06).** `output dpms off` leaves `output->enabled` set and never calls
  `output_disable()`, so by the source no evacuation should happen. Measured on
  the LG 38GN950 (DP, proprietary Nvidia): the monitor drops its DisplayPort
  link, the connector disappears, and sway destroys the output anyway
  (`Destroying output DP-1` in `session.log`, `get_outputs` empty). Any
  floating window is re-centred when the output returns, with no suspend
  involved, and `dpms on` cannot bring it back — the black screen needed a VT
  switch to recover. The idle hook was removed from `90-launch-apps.conf`
  (with a warning comment). Side effect worth knowing: an idle monitor-off
  longer than the next `save` also produced an **empty state file**
  (10-04 15:52 → 22:05 bedtime save wrote 0 windows, so the 10-05 resume had
  nothing to restore). Fixed the same day — see
  [Update 2026-10-06](#update-2026-10-06-output-loss-without-a-suspend).
- **No `output` config option prevents evacuation.** There is no
  "keep workspaces on this output" or "don't re-centre" setting; the behaviour is
  unconditional in the C, not policy.
- **Waiting for the geometry to "settle" does not help** — sway is not restoring
  anything later, the old coordinates are gone the moment the workspace touches
  the NOOP output. Nothing inside sway remembers them.

## The workaround

`bin/sway-float-geometry save|restore`, wired into the swayidle block in
`dotfiles/.config/sway/config.d/90-launch-apps.conf`:

```
before-sleep '~/bin/sway-float-geometry save; swaylock -f -c 000000; ~/bin/lock-secrets' \
after-resume '~/bin/conky-restart; ~/bin/sway-float-geometry restore'
```

`save` must come **before** `swaylock`, which blocks until unlock. State lives in
`$XDG_STATE_HOME/sway/float-geometry.json`, written via a temp file so a save
interrupted by the box going down cannot leave a truncated file.

Also bound manually for pinning a floating arrangement by hand:
`$mod+Alt+g` (save) / `$mod+Alt+Shift+g` (restore).

### Two things that were not obvious

**1. `con_id` survives a suspend.** Suspend/resume evacuates and re-adds
workspaces but does not destroy views, so container ids are still valid on
resume. Matching is therefore exact — no title or PID guessing needed for the
case this note is about. (There is a fallback to `app_id`+`class`+`title` for ids
that did vanish, but it deliberately refuses to act when that does not identify
exactly one window, rather than guessing between two identical terminals.)

**2. Feeding a saved `rect` straight back does not land the window there.**
`move absolute position` and `resize set` address the container box **including**
its titlebar, while `get_tree` reports `rect` **without** it. Measured live on a
`border normal` window with `current_border_width: 0` and a 16px `deco_rect`:

| issued | resulting `rect` |
| ------ | ---------------- |
| `move absolute position 300 300` | `x=300, y=316` |
| `resize set 600 500` | `595x480`, and **x/y shifted to 350,321** |

So position is off by the titlebar height, and `resize set` **re-centres the
window** — which is why the script always issues `resize` *before* `move` in the
same command list.

The first attempt hardcoded a decoration offset. That is wrong: `border pixel N`
has borders on all four sides and no titlebar, so the correction differs per
border style, and `deco_rect` is `0,0,0,0` for anything that is not
`border normal`. Instead the script **measures and corrects**: issue the naive
values, read the actual result, and re-issue `last_issued + (target - observed)`.
The offset is constant, so this converges in two passes for any border style,
with no decoration knowledge at all.

Apps that quantise their own size never converge exactly — foot snaps to
character cells (`600 → 595`, `500 → 480` above). The loop stops as soon as the
total error stops shrinking rather than fighting them, and reports those windows
as "not pixel-exact" instead of silently looping.

Verified live: a window displaced to `1200,816 399x270` was restored to
`900,316 714x540`, exactly matching the saved state, in two passes.

## Confirmed on real suspends

Two real cycles, from `~/.local/state/sway/float-geometry.log`:

```
2026-09-30 22:05:08 [save]    saved 1 floating window(s)
2026-10-01 13:25:24 [restore] restored 1 of 1 window(s)

2026-10-01 14:58:28 [save]    saved 3 floating window(s)
2026-10-01 20:13:42 [restore] restored 2 of 3 window(s)
```

The `after-resume` timing works: `--wait` for an active output was sufficient and
no sleep was needed. The correction passes behaved as designed, converging on
pass 2 and stopping on pass 3 when the error stopped shrinking (foot quantises
its height, so the last pixels never resolve — by design, not a failure).

The "2 of 3" was **not** a miss: the third window was Steam, already at its saved
`1104,196 1632x1231`, so nothing was issued for it. That exposed a reporting
flaw worth more than the finding — see below.

## Reporting: three outcomes, not one number

`restored N of M` conflated two different things, and a later `restore -n` even
claimed *"all 3 saved window(s) already in place"* when two of the three saved
`con_id`s no longer existed (the foot windows had been replaced, and the
uniqueness guard had correctly refused to match two identical `swayfloat/foot`
windows). Nothing matched, and it read as success.

The outcomes are now separated, because this message is the only evidence a
resume leaves behind:

```
3 saved: moved 1, 2 already in place
3 saved: 1 already in place, 2 not found
3 saved: 3 already in place
```

`not found` is the honest answer for a saved entry whose window is gone or cannot
be matched unambiguously.

## Update 2026-10-06: output loss without a suspend

The hooks-only design above failed in practice, for two reasons found in
`float-geometry.log` and `session.log`:

1. **An output can vanish with no suspend.** `output * dpms off` makes this
   monitor drop its DP link and sway destroys the output (see the DPMS dead end).
   Windows are re-centred when it returns and no hook fires. The idle DPMS hook
   is removed, but anything else that bounces the output (hotplug, a monitor
   power-cycle, a KVM) would do the same.
2. **`save` overwrote the good state with nothing.** With no output the tree has
   *no workspaces*, so `current_floats` returned `[]` and the 22:05 bedtime save
   (10-04) wrote an empty file, while a floating window was alive throughout. The
   next resume then logged `state file is empty, nothing to restore`, and that
   window sat re-centred (`1500,437` on a 3840 px output is exactly the centre)
   until the following save recorded the centred position as the new truth.

Fixes, all in `bin/sway-float-geometry`:

- **`save` refuses without an active output** (warning in the log, exit 0 so the
  hook never fails, previous state kept).
- **`watch` daemon**, started from `90-launch-apps.conf`. One loop handles
  `output` events (debounced 0.5 s) and a 2 s poll, strictly in order: *first*
  look at the outputs, and only if they are unchanged take a snapshot (every 30 s,
  written only when something changed). If the outputs were seen gone, or their
  ids changed, it restores instead. That ordering is what stops a re-centred
  window from ever becoming the "good" state.
- **Restores are serialized** with a `flock`, so the daemon and the
  `after-resume` hook (kept as a second path) cannot interleave their
  measure/correct passes.

Measured on this machine (sway 1.11):

| Fact | Consequence |
| ---- | ----------- |
| `output DP-1 disable` / `enable` re-centres floaters, same as the real thing | Usable as a safe test of the whole path |
| The output **id is unchanged** across a sway-level disable/enable, but **new** when the connector is re-created | The id alone is not enough; the daemon also remembers having seen *no* output |
| `swaymsg reload` emits one `output` event (`change: unspecified`) | Events are not a "something broke" signal; the daemon compares state and ignores it |
| Test: disable, 1.5 s, enable → `5 saved: moved 3, 2 already in place` | End to end works |

Limits worth knowing: a flap shorter than the 0.5 s debounce on an output whose id
does not change would go unnoticed (real DRM re-creations take about a second and
get a new id). A manual `$mod+Alt+g` save is no longer a pin — the next snapshot
replaces it.

## Update 2026-10-07: windows came back on the wrong workspace

First real suspend with the watcher: two floating terminals that lived on `#1 Desk`
reappeared on `#4 Create` (the workspace that was visible after unlock), and
`restore` reported success. Cause, reproduced with throwaway windows on a hidden
workspace:

**`move absolute position` re-parents a floating window to the workspace that is
*visible* on the output under its new position.** `restore` used to send
`move container to workspace "<saved>", resize …, move absolute position …`, so
the position move undid the workspace move one command later — for every window
on a hidden workspace, on every restore. (It also hit windows that only needed a
position fix and were already on the right hidden workspace.) The same effect
explains the 10-06 test, where windows saved on `#1` ended up on the visible `#4`.

Fixes in `cmd_restore`:

- **The workspace move goes last** in the command list, and is sent for every
  non-sticky window, so a position fix can no longer pull it away.
- A window that is only on the wrong workspace gets *just* the workspace move; no
  geometry command is sent at all.
- **A second restore no longer degrades the first.** Each process starts with no
  decoration offset, so its first pass sends naive values (+16 px y, −30 px
  height for foot) and "error no longer shrinking" used to stop right there, one
  pass short of the correction. The check now starts at the second pass. This is
  what left `629`/`628` 16 px low and 30 px short after the after-resume hook ran
  behind the watcher's restore.

Tested with throwaway floating windows: saved on a hidden workspace, displaced to
the visible one at a wrong position → restored to the right workspace and position;
displaced while on the hidden workspace → restored without leaving it.

Lesson for any script here: never rely on `move container to workspace` followed
by a position command; and a restore that only checks geometry will report
success for a window on the wrong workspace.

**Verified 2026-10-07**, two ways. (1) Real output disable/enable on a live layout
with windows on a hidden workspace: `moved 4, 1 already in place`, positions and
workspaces identical to before; two scratchpad windows stayed hidden throughout.
(2) A real short suspend: the after-resume hook restored (`moved 5`), then the
watcher saw the output change and found `6 already in place`. Not yet verified: an
overnight suspend, and a real connector loss (monitor standby). Scratchpad windows
are excluded on purpose: sway keeps their position across hide/show, so there is
nothing to restore.

Not recoverable: the workspaces recorded in the 22:05 save (the log lists
positions only), so the layout of that evening could not be reconstructed exactly.
Take a screenshot before testing a suspend.

## Open

- Nothing outstanding on the mechanism. Residual sub-pixel mismatch on
  size-quantising apps (foot) is expected and reported as
  `not pixel-exact (app-clamped size)`.
- Tiling layout is **not** covered. It survives suspend (only floaters are
  re-centred), so it is out of scope here; see `docs/TODO.md` §3 for the planned
  `bin/sway-layout`.

## See also

[`docs/reference/sway-window-placement.md`](../reference/sway-window-placement.md)
— the wider picture: what sway can and cannot do about window placement, why
`assign` beats `for_window` for workspace rules, and why no layout-restore tool
works for VS Code or browsers.
