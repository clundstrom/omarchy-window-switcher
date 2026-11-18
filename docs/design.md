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
`WorkspacePresentation.qml` reads the bounded visual settings from
`compact.json`. The Rust core in `rust/src/core.rs` handles history, ordering,
navigation, geometry and preview-change detection. `native/coreplugin.cpp` is
a thin Qt adapter, using generated CXX bindings to call Rust. Window objects
and capture sources stay in QML. The bridge passes only plain metadata and
returns indices, labels, history and normalised rectangles.

The core is stateless. The existing controller retains its session history
and opening snapshot, so there is no second history store to synchronise.
Source tokens distinguish native windows that reuse the same address without
passing native object pointers into Rust. The boundary rejects malformed or
oversized snapshots instead of panicking. Rust dependencies are compiled into
one local Qt module, with no additional service or runtime network access.

The layer is keyboard-exclusive on the focused monitor. Native global shortcuts
open/cycle the switcher without spawning a shell command. Separate modifier
trackers cover releases that occur before the layer receives keyboard focus;
the in-popup key surface also handles release. Workspace selection and
activation work through the keyboard or a left click on a preview.

`WorkspaceTapTarget.qml` accepts a left-button tap on release. It stays passive
while pressed, so a drag can scroll the horizontal view and cancel the tap.
Cards send their workspace key through the grid to the controller, which looks
up the current source and uses the existing close-and-activate path. A click
does not first move the keyboard selection or scroll the row. Closing disables
the tap targets and detaches captures before the target window is activated.
Later modifier release cannot override a clicked workspace because the session
is already closed. Hovering does not change selection, and the shortcut
inhibitor remains in place for desktop mouse gestures.

### Presentation

Flat previews sit in a horizontal row over a theme-coloured desktop backdrop.
Only the workspace number and a small selected dot appear below each preview.
The selected border uses the theme's image-picker selection colour. Nothing
fades or scales during opening or navigation.

`thumbnailWidth` in `compact.json` controls preview width from 160 to 960 logical
pixels before shell scaling. Native monitor proportions determine the height.
The layout also limits width by the available screen height, so a large setting
cannot make the preview taller than a smaller monitor. Scrolling follows the
selection using the plain workspace array and cell dimensions. It does not
query Qt's native model getter during position updates.

`overflowMode` selects `wrap` or `scroll`. The shipped settings use `wrap`, while
an omitted or invalid value preserves `scroll` for existing configurations.
Wrapped previews fill a row and continue below, using further rows if needed.
Selection never scrolls the grid or changes any preview's position. The layout
first keeps the configured preview size and the number of columns that fit.
If the rows exceed the monitor height, it considers more columns and smaller
previews to keep the grid visible. `maxVisible` limits columns. Capture scheduling
uses both coordinates and keeps the selected workspace first within the same
20-source budget. Wrapping disables dragging.

Scrolling overflow reserves roughly a fifth of a preview beyond the complete cards. The
half-gap is included in that allowance so image content, rather than empty
spacing, appears at the edge. When both ends have hidden workspaces, the extra
space is split between them. Selection stays among the complete cards near the
centre, and the content position is clamped at the first and last workspace.
Row width depends on screen space, preview settings and workspace count, never
selection. Small displays reduce the number of complete cards and, when needed,
preview width to leave space for the cue. The existing visible-card capture
budget also covers partially visible neighbours. No extra controls or motion
are introduced.

`setPreviewWidth` changes the width through the existing shell call interface
without reloading the plugin or changing its history. It is temporary. Editing
`compact.json` preserves the setting across restarts, but Omarchy may reload the
plugin when it notices a file change. The remaining settings control visible
card count, spacing, padding, border rounding, backdrop opacity and wallpaper
visibility.

An asynchronous image component preloads Omarchy's current wallpaper from its
existing file. A file watcher invalidates that image when the wallpaper changes.
Opening uses an already decoded image or the theme background for the entire
interaction, so a slow image cannot delay opening or pop in afterwards.
This is an in-memory wallpaper image, not a cache of workspace captures.
Unsupported formats, including video wallpapers, use the theme background.

Super+Backspace toggles the backdrop between its configured transparency and an
opaque theme background. Omarchy's stock window-opacity command targets regular
windows and cannot target this layer surface. The focused key surface handles
the same chord while the overlay is open, leaving the desktop binding unchanged.
Releasing a secondary modifier while the switching modifier is held does not
activate a workspace. The opacity choice is retained until the plugin reloads.

### Desktop shortcuts

Desktop mouse bindings run before QML pointer handling. A native Wayland
shortcut inhibitor blocks desktop gestures only while the overlay is open.
The four switcher bindings use `dont_inhibit = true` so cycling and modifier
release remain available. Normal desktop shortcuts and mouse-based resizing
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

The presentation passes thirty offscreen layout cases across both modes, including 5120×1440,
ordinary 16:9 sizes, five versus six workspaces, overflow, a one-card setting and
maximum-width previews on a 960×540 display. Each case checks the first, middle
and last selection, complete selected previews, visible slices in directions
with hidden workspaces in scrolling mode, and constant layout dimensions during
navigation. Wrapped cases also verify every preview is visible and its position
does not change with selection. The tests cover live resizing and model changes
where Qt can retain a non-zero content origin; scrolling and capture visibility
account for that offset.
Input tests cover forward/reverse cycling, the opacity chord, excluded
Backspace combinations and secondary-modifier release handling. These automated
checks do not establish compositor capture or physical shortcut behaviour.

The installed flat presentation was also inspected in the unlocked desktop
using in-memory screen captures. Native previews, the selected border and dot,
numeric labels and selection-following overflow were visible at widths of 400
and 600 pixels. Live checks resized the open overlay through 400, 600 and 960
pixels without changing its opening order. Forward/reverse Tab, native global
shortcut delivery and both opacity states passed. A held-modifier test checked
that releasing the extra opacity modifier kept the overlay open, then releasing
the switching modifier activated the current workspace and released captures
and inhibition. This test used virtual input for the focused key surface;
physical opening-shortcut delivery was not remeasured. Normal desktop bindings
were left unchanged. Numbers use the same subtle theme-coloured outline as
Omarchy's image picker to stay readable over bright content.

Overflow was inspected in the live desktop with six workspaces. Five complete
previews and a slice of the sixth were visible at the start, with the slice on
the opposite edge at the end. Forward/reverse wrapping, fixed opening order,
live resizing, opacity toggling and capture/inhibition cleanup passed live
checks. The preview slices reuse the existing native capture components.

Both overflow modes were then inspected in the live desktop with three occupied
workspaces and a temporary two-column limit. The wrapped view showed a complete
second row and the scrolling view showed the partial neighbouring preview.
Forward/reverse wrapping, frozen order, opacity and capture/inhibitor cleanup
passed in both modes. The temporary limit was restored to five afterwards,
with 800-pixel previews and wrapped overflow enabled in the installed settings.

Left-click activation passed focused pointer tests for activation on release,
drag cancellation, ignored hover/right clicks and disabled targets. A temporary
Wayland virtual pointer also checked the actual installed overlay in both
overflow modes. Clicking a preview different from the keyboard selection moved
to that workspace while the modifier was held. Releasing the modifier afterwards
kept the clicked workspace active. Captures and inhibition were released in
both modes. The pointer helper was used only for testing and is not part of the
plugin or its dependencies. No live right-click gesture was attempted.

The scoped gesture guard was checked in the live session: inhibition became
active with popup focus, Tab cycled selection, and closing released inhibition
and all capture sources. The normal desktop resize binding remains installed.
The fatal right-click gesture was not deliberately repeated. The crash stack
points into Hyprland's Lua resize dispatcher; its underlying cause remains
unconfirmed.

### Rust migration validation and comparison

The Rust core passed 16 unit tests, five Qt bridge checks, 230 comparisons
against the previous JavaScript implementation and all seven offscreen layout
cases. The manifest, interface checks, Rust formatting and Clippy checks also
passed. A full panel cannot be exercised with Quickshell's offscreen backend,
so the installed version was checked in the live desktop session as well.
Its actual previews were inspected using an in-memory screen capture. Forward
and reverse navigation, frozen ordering, modifier-release activation,
compositor global-shortcut delivery, capture cleanup and shortcut-guard cleanup
passed. The loaded native library was confirmed to come from the installed
plugin folder. Local keyboard bindings and the normal renderer were retained.

A fresh comparison measured 20 warm openings of each implementation with four
tracked windows and three regular workspaces displayed. The JavaScript version
was measured immediately before installing Rust in the same desktop session.
Each opening used explicit activation, waited 250 ms before reading status,
then closed and waited 120 ms before the next opening. Neither run switched
away from the original workspace.

| Measurement | JavaScript | Rust |
|---|---:|---:|
| Median opening logic | 1 ms | 1 ms |
| Median first-preview arrival | 36 ms | 35 ms |
| First-preview arrival, 95th percentile | 41 ms | 38 ms |
| First-preview arrival, observed range | 33–51 ms | 32–61 ms |

These measurements start inside the opening function and end when a native
preview reports content. They exclude shortcut delivery, final display
presentation and cold shell startup. Timing resolution is one millisecond.
The results do not demonstrate a meaningful speed improvement. Native renderer
startup remains the main delay. The Rust implementation is an architectural
change, with the existing interface and preview lifecycle preserved. Higher
window counts and other workloads need their own measurements.

### Opening-time profile before the Rust migration

On 18 November 2026, a live timing profile compared 20 openings before and
20 openings after starting the first capture batch immediately. The session
used Quickshell 0.3.2 on a 3440×1440 monitor at 240 Hz, with three tracked
windows and two regular workspaces displayed. Each opening used the host's
explicit activation mode and restored the original window on close.

Median first-preview arrival fell from 48 ms to 34 ms. The 95th percentile
fell from 51 ms to 36 ms, and the observed ranges were 46–62 ms before and
31–45 ms after. Opening logic took a median of 1 ms in both runs. These times
start inside the opening function and end when a native preview reports
content. They exclude shortcut delivery and final presentation on the display.

Temporary in-memory probes showed a 16–19 ms wait between geometry handling
and the first capture batch. The first images then arrived in 1–2 ms in the
instrumented baseline. The capture timer now triggers its first batch on
start. Later batches retain their 16 ms spacing and the existing capture
budget. Fresh geometry is still required before captures begin.

A separate read-only local socket test took a median of 0.09 ms to request
window data from Hyprland. Inside the shell, the native window-data signal
arrived around 1–2 ms after opening, but the deferred geometry callback usually
ran around 30 ms. This locates a remaining delay between notification and
callback execution. It does not establish which native rendering or event-loop
operation caused that delay. Rewriting the small workspace calculations in a
compiled language would not directly remove this scheduling gap.

This was a timing profile, not a sampled processor profile. The temporary
probes were removed before the final measurements. No debugger listener,
screenshots, persistent preview cache or new dependency was introduced.
Forward/reverse cycling, frozen order, modifier release, capture cleanup and
shortcut-inhibitor cleanup passed live checks. Code checks and all seven
offscreen layout cases passed. Larger window counts, other monitors and
different workloads still need separate measurements.

### Native renderer startup

A follow-up trace identified the scheduling gap. Window data arrived at about
2 ms, then Qt's interface thread entered its first frame synchronisation and
blocked for about 25 ms. The deferred geometry callback ran immediately after
that block. The renderer log placed about 22 ms inside creation of the new
OpenGL graphics renderer, with a few more milliseconds preparing its first
frame. Later openings showed the same pattern, rather than just a one-time
startup cost.

The installed Quickshell 0.3.2 build deletes the native layer window when it
is hidden. Opening it again creates a new window and render thread. This is a
deliberate workaround for a Qt/Wayland configuration error, documented in
[Quickshell's layer-window implementation](https://github.com/quickshell-mirror/quickshell/blob/2b4501a282689792b62e94f3fb30d8f512324fe6/src/wayland/wlr_layershell/wlr_layershell.cpp#L99-L106).
[Its base window implementation](https://github.com/quickshell-mirror/quickshell/blob/2b4501a282689792b62e94f3fb30d8f512324fe6/src/window/proxywindow.cpp#L270-L293)
performs that deletion. Qt's threaded renderer blocks the interface thread
until first-frame synchronisation completes.

Small native tests reproduced the cost without loading the plugin. Creating
Qt's OpenGL renderer on each of ten fresh worker threads took about 20–24 ms.
Creating ten renderers on one worker thread took about 20 ms for the first
and 0.4–0.5 ms for the rest. A separate context test and timing wrapper located
most of the fresh-thread cost inside `eglMakeCurrent`, called internally while
Qt creates the OpenGL context. Its first use on a new worker thread took about
19–24 ms after the initial process startup. This establishes the expensive call
and its connection to fresh threads, rather than a particular internal driver
routine.

The remaining delay is therefore mainly repeated native graphics startup.
Moving the workspace calculations to another language would leave that path
in place. A lasting improvement would need to preserve or reuse rendering
resources in Qt or Quickshell while retaining correct Wayland surface handling.
The plugin continues to unmap its window and release preview sources on close.

Qt also provides a supported single-threaded render loop, selected by starting
the shell with `QSG_RENDER_LOOP=basic`. A temporary live comparison used the
unchanged plugin for 20 openings, with three tracked windows and two regular
workspaces displayed. Median first-preview arrival was 9.5 ms, the 95th
percentile was 11 ms, and the observed range was 8–22 ms. The deferred geometry
callback ran at a median of 5 ms. These are preview-content arrival timings,
not complete shortcut-to-display latency.

This mode renders on the interface thread rather than creating a dedicated
render thread for each window. It applies to the entire shell, including the
bar, menus and lock screen. The timing test does not establish responsiveness
under other shell workloads. The default render loop was restored after the
comparison, and all temporary probes and logging overrides were unloaded.
No persistent render-loop setting was added. See
[Qt's render-loop documentation](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html#scene-graph-and-rendering)
for the supported modes.

## Updates

The Rust implementation lives on `main`. Build it with `bin/build`
before enabling it. Cargo downloads the locked build dependencies on the first
build. Build artifacts stay in the user cache because Omarchy rejects symlinks
inside plugin folders. The build generates a local module directory file that
points to this checkout's compiled library, allowing Quickshell's embedded
interface components to load it without changing global import paths.

Update an installed Rust checkout explicitly:

```bash
git -C ~/.config/omarchy/plugins/community.window-switcher fetch origin
git -C ~/.config/omarchy/plugins/community.window-switcher merge --ff-only origin/main
~/.config/omarchy/plugins/community.window-switcher/bin/build
omarchy restart shell
```

Preserve or commit local `compact.json` changes before updating. Omarchy's normal
plugin updater does not compile Rust modules. Rebuild explicitly after source
updates and Qt upgrades. The fork's default `main` branch contains the Rust
implementation. The previous JavaScript version remains available at commit
`4538d70`, and the earlier compact redesign is preserved at `5688690`. Incorporate upstream
changes deliberately in the development checkout, validate, then push the
reviewed branch. Avoid forced checkouts or hard resets over customizations.

QML edits may require a shell restart on installed Quickshell versions that
retain compiled components after a plugin rescan. Files in the user plugin
directory survive ordinary configuration reloads.

## Rollback

Commit `516bab9` preserves the larger previews before wrapped overflow was added.

The flat presentation before overflow cues is preserved at commit `86609ae`.

To restore the Rust implementation's earlier compact appearance, use commit
`1590d15` and restart the shell. Keep any uncommitted settings before changing
versions. This checkpoint uses the same native module and bindings.

```bash
git -C ~/.config/omarchy/plugins/community.window-switcher switch --detach 1590d15
omarchy restart shell
```

To return to the working JavaScript version, switch the installed checkout to
commit `4538d70` and restart the shell. Both versions use the same
plugin identity and bindings. The generated native library is unused by the
JavaScript version.

```bash
git -C ~/.config/omarchy/plugins/community.window-switcher switch --detach 4538d70
omarchy restart shell
```

To return to the current Rust implementation, switch to `main`, run `bin/build`
in the plugin directory and restart the shell.

The earlier compact redesign checkpoint is `5688690`. Back up the current plugin and personal bindings
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
