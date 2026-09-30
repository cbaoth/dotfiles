---
title: Sway window placement, criteria and layout persistence
hosts: [all]
status: resolved
tags: [sway, wayland, window-rules, criteria, layout, session]
updated: 2026-09-30
---

# Sway window placement, criteria and layout persistence

What sway can and cannot do about putting windows where you want them, and why
the obvious answers do not work. Every claim about sway internals here was read
from the `swaywm/sway` source at tag **1.11** and confirmed against the local
install — not taken from `sway(5)`, which is wrong on one important point.

No `setup/` module: this is all config fragments and scripts inside the repo,
deployed by `dotfiles-link`. There is nothing idempotent to install.

## Verdict up front

- **Workspace placement:** use `assign`, not `for_window … move container to
  workspace`. They are *not* equivalent, despite what `sway(5)` says.
- **Layout restore:** nothing native. i3's `append_layout` does not exist in
  sway and never will. No third-party tool solves it for single-process
  multi-window apps (VS Code, browsers) — that limit is fundamental, not a bug.
- **Floating geometry across suspend:** broken by sway, worked around by
  `bin/sway-float-geometry`. See
  [sway-floating-geometry-on-resume](../troubleshooting/sway-floating-geometry-on-resume.md).

## Feature availability

| Feature | Availability | Effort | Notes |
| ------- | ------------ | ------ | ----- |
| Static app → workspace | **native** | XS | `assign`. ✅ in use |
| Rule does not re-fire after a manual move | **native (partial)** | XS | `assign` fixes title-change + reload; a real remap still re-fires |
| Launch app *onto* a workspace | **native** | XS | `swaymsg 'workspace 3; exec code'` — PID/xdg-activation. Fails for a 2nd window of a single-instance app |
| Generic dialog/utility matching | **native** | S | `window_type` — see [Criteria](#criteria) |
| "Executable name" criterion | **impossible** | — | No such attribute. Closest: `pid` + `/proc/<pid>/exe` from a script |
| Distinguish identical-looking windows | **impossible** | — | If `app_id`+`class`+`instance`+`title` all match, sway cannot tell them apart. Only escape: `mark` them yourself |
| Floating position/size restore | **native cmds + scripts** | S | `bin/sway-place`, `bin/sway-float-geometry` |
| Reproduce container tree (splits, nesting) | **self-implemented** | L | No placeholders — see [append_layout](#append_layout-does-not-exist-in-sway) |
| Reproduce `tabbed`/`stacked` | **self-implemented** | M | `layout tabbed` after the container exists |
| Reproduce order within a container | **self-implemented** | M | `move left/right` walks; no "insert at index" |
| Reproduce split ratios | **self-implemented** | M | `resize set <n> ppt` top-down, shallowest first, last child left unsized |
| Snapshot/restore *running* windows | **self-implemented** | M | Planned: `bin/sway-layout`. `con_id` makes matching exact within a session |
| Automatic periodic snapshot | **self-implemented** | S | systemd user timer over the above |
| Relaunch + match across reboot | **3rd party / self, all lossy** | L | The hard wall — see [Third-party tools](#third-party-tools) |
| Per-app session content (folders, tabs) | **app-side, already works** | — | VS Code and Firefox restore their own windows; only *placement* is the problem |
| True window identity across reboot | **impossible today** | — | [`xdg-session-management-v1`](#the-real-upstream-fix) |
| Scratchpad state | **uncaptured** | — | Every tool surveyed skips it |

## `assign` vs `for_window`

`sway(5)` claims:

> `assign <criteria> → <workspace>` … This command is equivalent to:
> `for_window <criteria> move container to workspace <workspace>`

**It is not.** They are different criteria *types* with different evaluation
points, and the difference is exactly the "window I moved by hand magically
jumps back to its assigned workspace" bug.

### Why `for_window` re-fires

`for_window` rules are `CT_COMMAND` criteria, run by `view_execute_criteria()`
(`sway/tree/view.c:508`). It guards against re-running via a per-view
`executed_criteria` list — and that guard leaks in two places:

1. **`view_unmap()` clears it outright** (`sway/tree/view.c:912`):

   ```c
   void view_unmap(struct sway_view *view) {
       wl_signal_emit_mutable(&view->events.unmap, view);
       view->executed_criteria->length = 0;
   ```

   So **any unmap/remap re-runs every matching rule.** XWayland views remap on
   reparenting, tray hide/show and some fullscreen transitions — which is the
   "sway thinks it is a new window even though it looks identical" case.

2. **The guard compares criteria by pointer**
   (`view_has_executed_criteria()`, `view.c:497`), and `swaymsg reload`
   `criteria_destroy()`s and rebuilds `config->criteria`
   (`sway/config.c:163-167`). After a reload every view's guard list holds stale
   pointers that can never match, so **the next title change re-runs all
   rules**. Browsers and VS Code change titles constantly, so in practice this
   fires within seconds of a reload.

   `view_execute_criteria()` is called from `handle_set_title` in *both*
   `sway/desktop/xdg_shell.c:345` (Wayland-native) and
   `sway/desktop/xwayland.c:685`, plus `set_class`, `set_role` and
   `set_window_type` in the XWayland path. (i3 has the same class of bug —
   [i3#3628](https://github.com/i3/i3/issues/3628).)

### Why `assign` does not

`cmd_assign` (`sway/commands/assign.c`) creates `CT_ASSIGN_WORKSPACE`,
`CT_ASSIGN_WORKSPACE_NUMBER` or `CT_ASSIGN_OUTPUT`. Those are read **only** by
`select_workspace()` (`sway/tree/view.c:571`) at map time.
`view_execute_criteria()` filters on `CT_COMMAND` and therefore never sees them.

| Trigger | `for_window … move container to workspace` | `assign` |
| ------- | ------------------------------------------ | -------- |
| Title change | re-fires (after a reload) | never |
| `swaymsg reload` + title change | re-fires | never |
| Class / role / window-type change (XWayland) | re-fires | never |
| Unmap → remap | re-fires | re-fires (both go through `view_map`) |

So `assign` is a strict improvement at zero cost, but **not a complete fix**: a
genuine remap still moves the window. Closing that needs an IPC daemon that
marks manually-moved windows and refuses to re-place them — see `docs/TODO.md`
§3.

### Authoring consequence

`assign` takes **no command list**, so any rule that also sets window state must
be split. Keep the criteria identical in both halves:

```
assign     [class="(?i)^steam_app_"]  → workspace $ws6
for_window [class="(?i)^steam_app_"]  fullscreen enable, border normal 0
```

Non-placement `for_window` rules (`$float`, `$pop*`, `$stick`, `$poptray*`,
`inhibit_idle`, `no_focus`) are left alone: they are idempotent, so re-firing is
harmless, and `assign` cannot express them.

The `→` (U+2192) is optional and cosmetic. `$var` substitution works in the
target (it is outside the `[...]`), so `→ workspace $ws6` resolves normally —
unlike variables *inside* criteria values, which do not substitute.

## Criteria

All 15 attributes from `sway(5)` CRITERIA. This repo currently uses 5.

| Attribute | Used here | Notes |
| --------- | --------- | ----- |
| `app_id` | ✅ heavily | Wayland-native only |
| `class` | ✅ | X11 only, needs XWayland |
| `instance` | ✅ (1 rule) | X11 only |
| `title` | ✅ | Regex. Changes at runtime — the re-fire trigger above |
| `window_role` | ✅ (1 rule) | X11 only |
| **`window_type`** | ❌ | `normal`/`dialog`/`utility`/`toolbar`/`splash`/`menu`/`dropdown_menu`/`popup_menu`/`tooltip`/`notification`. **The generic "is this a dialog" handle** — removes the need for one rule per dialog |
| **`shell`** | ❌ | `xdg_shell` or `xwayland`. Cleaner discriminator than maintaining paired `app_id`/`class` rules |
| `pid` | ❌ | Numeric. The bridge to `/proc/<pid>/exe` for scripts |
| `floating` / `tiling` | ❌ | Match by current state |
| `con_id` | (runtime) | Internal container id; what `bin/sway-*` scripts target |
| `con_mark` | (runtime) | `bin/sway-wstate` uses `_sheer*` marks as opacity state |
| `id` | ❌ | X11 window id |
| `urgent` | ❌ | |
| `all` | ❌ | Matches everything |

There is **no executable-name criterion**. The closest thing is `pid` plus
`/proc/<pid>/exe` resolved by a script, which then issues a runtime
`swaymsg '[pid=N] …'`.

Two gotchas already documented in the header of
`dotfiles/.config/sway/config.d/70-window-rules.conf`, repeated here because
they cost an evening each: matching is an **unanchored substring** search, and
`\b` is silently eaten by the config parser (it works only in ad-hoc runtime
`swaymsg`).

## `append_layout` does not exist in sway

i3's layout restore works by pre-building a tree of **placeholder** containers
carrying per-window `swallows` criteria; relaunched apps then get "swallowed"
into their placeholder. That is the only clean way to reproduce a nested layout,
and **sway does not have it**:

- [PR #3022](https://github.com/swaywm/sway/pull/3022) implemented it and was
  **closed unmerged** in June 2020. ddevault: *"I'm still not fond of this
  idea… The complexity this introduces to the codebase is remarkable."*
- [Issue #1005](https://github.com/swaywm/sway/issues/1005) is still open.
- Confirmed locally: `swaymsg 'append_layout /x'` →
  `Unknown/invalid command 'append_layout'`, and `/usr/bin/sway` contains no
  `append` command string.

Everything else therefore has to build the tree imperatively with `splith` /
`splitv` / `move` / `focus` / `layout tabbed`, which cannot create an empty
container and has no "insert child at index" — hence the L-sized effort in the
table.

## Third-party tools

Surveyed 2026-09-30. None are installed.

| Tool | Language | Verdict |
| ---- | -------- | ------- |
| [sway-session-restore](https://github.com/kamposlargos/sway-session-restore) | Python | **Most technically honest.** Two-phase anchor+subtree restore, ratio-based top-down resize, PWA matching via Chrome's `--app`. Tiny project (0 stars, ~15 commits) |
| [swayrst](https://github.com/Nama/swayrst) | Python | Most-used (~84 stars). Author states outright that identifying the same windows after a reboot is unsolved |
| [swaymnesia](https://github.com/Microwonk/swaymnesia) | Rust | 7 commits. Restores layout but explicitly *not* sizes |
| [marang/sway-session](https://github.com/marang/sway-session) | Go | Pre-1.0. Drags in Herdr + optional AppArmor. Too heavy for this |
| [sway-layout](https://bruant.info/2026/01/19/sway-layout/) | Go | **Best idea:** launch everything in parallel, PID-track via the sway event stream, then re-arrange once all windows are up — no `sleep`-based races. Worth copying the approach |
| [tileroot](https://github.com/Hinikaa/tileroot) | C++17 | ⛔ **Do not install.** Its README claims it uses sway's `append_layout` swallowing, which does not exist (above). Also pulls in libX11 for a Wayland tool and advertises "byte-for-byte identical dumps" and its test count as features. Reads as generated slop |

### Why none of them fit

VS Code and browsers serve **N windows from one process**. So
`/proc/<pid>/cmdline` yields a single command and cannot say which window is
which — and that is precisely the case that matters here (several VS Code
workspaces, several browser windows). The only discriminator is the window
title, which means a hand-curated regex map no matter which tool is used.

Hence the local plan: start with snapshot/restore of **already-running** windows
only (`con_id` matching is exact within a session, no relaunch, no guessing) and
add title-regex relaunch later only if that proves insufficient.

## The real upstream fix

[`xdg-session-management-v1`](https://wayland.app/protocols/xx-session-management-v1)
lets a client ask the compositor to restore a toplevel's prior state before it
is mapped, which solves window identity across restarts *properly* — the
compositor holds the state, so no PID or title guessing is involved.

- Merged in **KWin** (shipped with Plasma 6.4) and **Mutter**.
- Firefox is tracking it:
  [bugzilla 1959841](https://bugzilla.mozilla.org/show_bug.cgi?id=1959841).
- **No sway/wlroots implementation.** This is the thing to watch; it obsoletes
  most of this note.

## See also

- `dotfiles/.config/sway/config.d/70-window-rules.conf` — the rules, with the
  condensed version of the `assign` finding in its header
- [sway-floating-geometry-on-resume](../troubleshooting/sway-floating-geometry-on-resume.md)
  — the suspend/resume geometry loss and its workaround
- `bin/sway-winfo` (`$mod+F8`) — live criteria inspector, copies a ready-made
  criteria block to the clipboard
- `docs/TODO.md` §3 — the open items
