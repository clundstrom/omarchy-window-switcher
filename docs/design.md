# Design and maintenance

## One feature

The plugin switches occupied regular workspaces in most-recently-used order.
It retains forward/reverse cycling, modifier-release activation
and native workspace previews. Search, filters,
individual-window navigation, alternate views, naming and window-close controls
are outside this fork's scope.

`manifest.json` keeps the overlay loaded so MRU history survives between uses.
`Switcher.qml` owns selection, frozen opening order, activation and the layer
surface. `WindowRecords.qml` reads the compositor's window and monitor data;
`CompositorSignals.qml` handles changes. `WorkspaceGridView.qml` schedules the
horizontal strip and `WorkspaceCard.qml` composes native window captures.
`WorkspacePresentation.qml` reads the six bounded visual settings from
`compact.json`. The small JavaScript models handle MRU, navigation, geometry
and record reuse.

The layer is keyboard-exclusive on the focused monitor. Native global shortcuts
open/cycle the switcher without spawning a shell command. Separate modifier
trackers cover releases that occur before the layer receives keyboard focus;
the in-popup key surface also handles release. Workspace selection and
activation are keyboard-driven.

### Super-modifier compatibility

Desktop mouse bindings run before QML pointer handling. A native Wayland
shortcut inhibitor blocks desktop gestures only while the overlay is open.
The four switcher bindings use `dont_inhibit = true` so cycling and modifier
release remain available. Normal desktop shortcuts and Super+right-drag resizing
resume when the overlay closes. This guards the observed Hyprland 0.56.2 Lua
resize-dispatcher crash path without globally disabling the resize gesture.
Install the updated bindings together with the QML change. The inhibitor is
compositor-managed; bindings explicitly marked `dont_inhibit` bypass it.

## Performance and privacy

The opening path does no desktop-entry matching or app-icon refresh. Capture
work is limited to visible cards and prioritizes the selected workspace.
Captures use native `ScreencopyView` sources with a bounded budget and batching.
The popup appears immediately rather than waiting for all preview frames.
The supplied Hyprland layer rule disables animations only for the switcher's
namespace, and the QML contains no opening or thumbnail fade.
Sources are released when the interaction closes; there is no persistent
thumbnail cache, network access, telemetry, OCR, disk screenshot output or
additional runtime process.

Keep preview rectangles in monitor coordinates until composition, preserve the
monitor aspect ratio and clip offscreen content to the workspace canvas. A
scrolling window must not be moved into view just to fit its thumbnail.

## Validation

Run the model, contract, manifest and QML checks, plus the offscreen strip test:

```bash
PATH=/usr/lib/qt6/bin:$PATH ./test/all
./test/presentation
```

An offscreen geometry test cannot validate Wayland capture, actual colors or
compositor focus. In the live session, check repeated forward/reverse cycling,
quick modifier release, pointer movement,
workspace removal, tiled/floating/scrolling layouts and capture cleanup.
Observe the actual overlay before claiming visual correctness. Check ordinary
and ultrawide logical sizes, and test mixed-scale monitors when available.

`status()` exposes bounded in-memory lifecycle diagnostics. Use those to
separate shortcut delivery, model work, capture arrival and focus behavior;
measurements are specific to the machine and current workload.

The initial live checks on a 3440×1440 monitor observed the corrected native
three-column preview, 1–3 ms of controller work, and first captured frames in
54–68 ms. First-frame timing measures capture arrival, not pixels reaching the
display. Forward/reverse navigation, frozen order and capture cleanup
were checked live. Physical 5120×1440 and mixed-monitor behavior need hardware
validation; their logical geometry is exercised offscreen.

The offscreen test also covers empty/shrinking workspace lists and closing
capture sources. Capture scheduling reads a plain input array rather than
`GridView.model`: reading Qt's model getter from a content-position binding
during model replacement caused a reproducible native crash in the test.

The scoped gesture guard was checked in the live session: inhibition became
active with popup focus, Tab cycled selection, and closing released inhibition
and all capture sources. The normal Super+right-drag binding remains installed.
The fatal right-click gesture was not deliberately repeated. The crash stack
points into Hyprland's Lua resize dispatcher; its underlying cause remains
unconfirmed.

## Updates

The focused implementation lives on `refactor/workspace-only`, the fork's default branch.
Keep the installed copy on that branch and update it explicitly:

```bash
git -C ~/.config/omarchy/plugins/community.window-switcher fetch origin
git -C ~/.config/omarchy/plugins/community.window-switcher merge --ff-only origin/refactor/workspace-only
omarchy restart shell
```

Preserve or commit local `compact.json` changes before updating. Omarchy's normal
plugin updater fetches `origin HEAD`, which now follows the focused branch,
and attempts a fast-forward. The original upstream main and the redesign
checkpoint remain separate branches. Incorporate upstream
changes deliberately in the development checkout, validate, then push the
reviewed branch. Avoid forced checkouts or hard resets over customizations.

QML edits may require a shell restart on installed Quickshell versions that
retain compiled components after a plugin rescan. Files in the user plugin
directory survive ordinary configuration reloads.

## Rollback

The last working redesign checkpoint is `5688690` on
`redesign/compact-workspaces`. Back up the current plugin and personal bindings
before switching versions. To restore its code without overwriting uncommitted
changes:

```bash
git -C ~/.config/omarchy/plugins/community.window-switcher switch --detach 5688690
```

Restore the matching pre-refactor workspace bindings backup as well: that
checkpoint opens through `omarchy-shell shell summon` and does not register the
new `next-workspace`/`previous-workspace` global shortcuts. Its modifier trackers
use the same two names. Then run `hyprctl reload`, `hyprctl configerrors` and
`omarchy restart shell`. Restore only the switcher block if unrelated personal
bindings have changed since the backup.
Remove the switcher-specific no-animation layer rule as well if restoring the
old compositor fade is desired.
