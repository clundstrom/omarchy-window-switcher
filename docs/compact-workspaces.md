# Compact workspace presentation

The workspace view is a centered horizontal strip. The existing controller,
MRU ordering, workspace/window enumeration, activation targets, key surface and native
ScreencopyView sources remain in use. Window and grouped views retain their
original presentation.

## Architecture and installed baseline

The installed checkout was based on upstream `93d286a`, with local plain-text
rendering fixes, reverse-opening selection, and protection against pointer hover
changing modifier-release selection. Those changes are preserved in a separate
baseline commit before this redesign. Do not replace them with an upstream copy.

Presentation changes are confined to:

- `Switcher.qml`: compact panel dimensions, centered placement, optional chrome,
  context line, immediate appearance and compositor modifier tracking.
- `CompositorSignals.qml`: observe the initial geometry reply to start compact
  captures early, retaining the original settle timer as a compatibility fallback.
- `WorkspaceGridView.qml`: one horizontal row using the existing selection reveal.
- `SwitcherViewArea.qml`: compact sizing from existing logical monitor rectangles.
- `WorkspaceCard.qml`: one-line metadata, optional details/controls, native preview
  composition, and a short first-frame fade without transient large app icons.
- `CardFrame.qml`: compact selection with one thin accent border, without dimming,
  growth or an outer ring. The original frame remains available in other views.
- `WorkspacePresentation.qml`: bounded, watched local visual settings.

The fullscreen transparent layer still owns keyboard focus and outside-click
cancellation on the focused monitor. Only the small centered strip is painted;
compact mode does not dim the rest of the desktop. Capture limits, batching
size and source teardown are preserved. Compact mode starts the first capture
pass after the compositor client snapshot is applied and batches two sources
per 16 ms rather than 40 ms. The original 160 ms geometry timer remains a
fallback on Quickshell versions that do not re-emit the observed address signal.
No frame-readiness delay is added to opening or keyboard handling. Compact
closing no longer waits for the original 140 ms animation when no exit
animation is drawn. Modifier release can close a release-mode interaction regardless of popup
keyboard focus. Pointer movement does not cancel an interaction; intentional
inline name editing is exempt from native release activation.

## Settings

Edit `compact.json` in the installed plugin directory. These are presentation
settings, separate from the existing invocation/controller options. This also
works with Omarchy's scoped third-party API, which does not expose shellConfig.
Keep the existing Super+Tab invocation and Alt+Tab window bindings. To close a
release-mode popup even when its modifier was released before keyboard focus
arrived, append [modifier-release.lua](modifier-release.lua) once to the user
Hyprland bindings. These two transparent, non-consuming global shortcut bindings
track only Super_L/Super_R and spawn no processes. Then run:

```bash
hyprctl reload
hyprctl configerrors
```

The ordinary in-popup release handling remains a fallback. The native tracker
is needed to cover releases that happen before that popup receives focus.

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Enable compact workspace presentation; false restores the original workspace grid. |
| `thumbnailWidth` | `264` | Preferred logical card width, bounded to 160–400 and scaled with shell typography. |
| `maxVisible` | `5` | Strip width cap in cards, bounded to 1–8; extra cards scroll into view when selected. |
| `spacing` | `12` | Logical horizontal cell spacing, bounded to 4–32. |
| `padding` | `16` | Panel inset, bounded to 8–40. |
| `cornerRadius` | `16` | Panel rounding, bounded to 0–32. |
| `backgroundOpacity` | `0.96` | Multiplier for the theme menu background alpha, bounded to 0.5–1. |
| `showHeader` | `false` | Restore the existing search/filter/view controls. |
| `showFooter` | `false` | Restore keyboard hints. |
| `showDetails` | `false` | Restore counts, monitor metadata, miniature identity icons and hover titles. |
| `showCloseButtons` | `false` | Restore the existing confirmed workspace close control. |

Typing and filtering still work with the header hidden; a short context line
appears only while needed. F2/right-click naming, reverse navigation,
cancellation and miniature pointer actions remain available. Ctrl+W/Ctrl+G can
still switch to the existing other views. The first native frame arrives
asynchronously; compact mode shows the workspace canvas during startup, then
fades in that frame over 80 ms, respecting disabled shell animations. It does
not briefly substitute an app icon. Capture-disabled mode and detailed mode
retain icon fallbacks. No thumbnails are saved or cached on disk.

Color.menu background/text/border/selectedText and Color.accent remain live
Omarchy theme bindings. Background alpha is multiplied rather than replaced.
A light theme follows its own palette. Mixed-monitor previews keep their own
native aspect within a row sized for the tallest workspace.

## Validation and limitations

Run the existing checks and the real QML layout harness:

```bash
PATH=/usr/lib/qt6/bin:$PATH ./test/all
./test/presentation
```

The layout harness runs temporarily offscreen and verifies single-row layout,
vertical fit and selection-following overflow at 5120×1440, 1920×1080,
1280×720 and 960×540, including one and twelve workspaces. It does not validate
actual Wayland capture, theme appearance or multi-monitor focus. Standalone
shell singleton initialization can emit theme warnings; observe the plugin in
the real shell as well. The ordinary lint command also emits existing dynamic
Omarchy import/type warnings; runtime validation is required.

Live validation on a 3440×1440 monitor observed native workspace compositions,
selection, stable MRU order throughout an opening, repeated forward/reverse
navigation, Escape cancellation, modifier-release activation and capture budget
returning to zero after close. The user confirmed the normal workspace shortcut
works. Before/after captures were inspected only in memory. Physical 5120×1440,
mixed-scale multi-monitor behavior, unsupported capture and destroyed sources
need additional hardware/session testing. The geometry/capture implementation
and its existing safety checks were preserved. A delayed-release race was
identified in the existing in-popup-only release path; native modifier tracking
was added. Repeated physical-key and pointer validation remains necessary.
Memory-only, bounded lifecycle diagnostics are exposed by the existing status
method to help diagnose intermittent focus/release issues; no keys or titles
are added to those events and nothing is persisted.

## Fork and updates

Keep `upstream` pointed at devmobasa's repository and `origin` at your fork.
The redesign lives on `redesign/compact-workspaces`; upstream main stays separate.
Omarchy's updater fetches `origin HEAD` and attempts only a fast-forward merge.
It cannot silently replace a divergent redesign branch with upstream main;
local settings changes also prevent conflicting updates. Do not use a hard
reset, forced checkout, or reinstall over this directory to update it.

To update the installed copy from the reviewed redesign branch:

```bash
git -C ~/.config/omarchy/plugins/community.window-switcher fetch origin
git -C ~/.config/omarchy/plugins/community.window-switcher merge --ff-only origin/redesign/compact-workspaces
omarchy restart shell
```

To incorporate new upstream releases, fetch upstream into the development
checkout, merge or cherry-pick deliberately on the redesign branch, run the
checks, and push that branch. Keep local `compact.json` adjustments committed
on a personal branch or saved separately before applying updates.

## Rollback

For a presentation-only rollback, set `enabled` to `false` in `compact.json`.
For an exact restoration of the installed baseline, restore the complete
pre-change plugin backup, preserving a copy of the current directory first,
and run `omarchy restart shell`. Remove the two modifier-tracking bindings
added from `modifier-release.lua`, then run `hyprctl reload` and
`hyprctl configerrors`. Restore the original personal bindings backup only if
there have been no unrelated changes since it was made.

Some installed Quickshell versions retain compiled plugin components after a
plugin rescan; a shell restart was necessary in this session to load edited QML.
Normal shell/config reloads retain files in the user plugin directory.
