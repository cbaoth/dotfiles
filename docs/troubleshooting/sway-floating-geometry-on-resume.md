---
title: Floating windows pile up in the centre after suspend/resume (sway)
hosts: [motoko]
status: workaround
tags: [sway, wayland, suspend, floating, output, swayidle]
updated: 2026-09-30
---

# Floating windows pile up in the centre after suspend/resume

**Verdict: workaround.** Sway destroys floating geometry whenever an output goes
away and comes back — which is what a suspend/resume does. Upstream closed this
as *not planned*, so it can only be fixed from outside sway.
`bin/sway-float-geometry` saves the geometry on `before-sleep` and puts it back
on `after-resume`, driven by the existing swayidle hooks.

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

- **It is not DPMS.** The obvious suspect was
  `timeout 3600 'swaymsg "output * dpms off"'` in the swayidle block. It is not
  the cause: `output dpms off` leaves `output->enabled` set and never calls
  `output_disable()`, so no evacuation happens. Only the physical
  connector loss on suspend/resume does.
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

## Open

- The restore runs from `after-resume`, which may fire *before* sway has finished
  re-adding the output. `restore` polls `swaymsg -t get_outputs` for an active
  output with a non-zero rect (`--wait`, default 5s) rather than sleeping a
  guessed interval, and the correction passes absorb a late re-centre. Whether
  that is sufficient in practice needs a few real suspend cycles — if windows
  still end up centred, raise `--wait` before adding a sleep.
- Tiling layout is **not** covered. It survives suspend (only floaters are
  re-centred), so it is out of scope here; see `docs/TODO.md` §3 for the planned
  `bin/sway-layout`.

## See also

[`docs/reference/sway-window-placement.md`](../reference/sway-window-placement.md)
— the wider picture: what sway can and cannot do about window placement, why
`assign` beats `for_window` for workspace rules, and why no layout-restore tool
works for VS Code or browsers.
