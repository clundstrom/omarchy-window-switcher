# Omarchy Workspace Switcher

Workspace Switcher lets you move between your recently used workspaces in
Omarchy. Hold Alt and press Tab to open a row of workspace previews
in the centre of the focused monitor. Keep pressing Tab to move through them,
then release Alt to switch to the highlighted workspace.

You can also configure it to switch between individual windows, in recent-use
order, like a conventional Alt+Tab switcher. Window mode shows only open,
non-minimised windows on regular workspaces. Scratchpads, special workspaces and
windows with no regular workspace are excluded. It does not list processes or
background services.

Workspace Switcher uses Rust for recent-use history, ordering, selection and preview
layout calculations. It keeps the existing Qt interface and window capture
components. A small compiled module connects them, without running a separate
background program.

The interface shows flat previews over a dimmed desktop. Each preview has a
workspace number underneath it, or a window title in window mode. A thin
theme-coloured border and a small dot mark the selection. There are no headers,
instructions or extra controls.

<details>
<summary>Screenshot of the earlier compact appearance</summary>

![Earlier compact Workspace Switcher appearance](docs/images/workspace-switcher.png)

</details>

Each preview uses images of the workspace's windows and the layout reported by
Hyprland. This includes tiled and floating windows. Windows that extend beyond
the screen, such as those in a scrolling layout, are clipped at the preview's
edge. Previews keep the screen's proportions and use colours from your Omarchy
theme. They are captured when needed rather than streamed in the background.
The current Omarchy wallpaper fills the spaces between windows when available.

The layout adapts to the monitor's size. By default, extra previews continue
below on another row. They stay in place as you cycle, with only the selection
border and dot changing. A scrolling layout is also available, with a slice of
the next preview at the edge to show that more workspaces are available.
It opens without a fade animation.
Only eligible windows and workspaces appear. Their order stays fixed until you
finish switching. Window previews preserve each window's proportions within
the same cards, and use both overflow layouts and left-click activation.

## Installation

You need Omarchy with its Quickshell plugin system and Hyprland's window preview
support. The plugin requires version 1 of Omarchy's plugin format. More details
about compatibility are in the [design notes](docs/design.md).

Builds need Rust, Cargo, a C++ compiler and the Qt development tools supplied
with Omarchy. If Rust is not installed, you can install it under your user
account with `mise install rust@stable`.

For a new installation, run:

```bash
git clone --branch main https://github.com/clundstrom/omarchy-window-switcher.git \
  ~/.config/omarchy/plugins/community.window-switcher
~/.config/omarchy/plugins/community.window-switcher/bin/build
omarchy plugin enable community.window-switcher
```

Copy the contents of [docs/bindings.lua](docs/bindings.lua) into
`~/.config/hypr/bindings.lua`, replacing any older switcher bindings. Then reload
the configuration and restart the shell:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

Resolve any errors reported by `hyprctl configerrors` before using the switcher.
The supplied bindings replace Omarchy's Alt+Tab navigation with this switcher's
configured mode. The installed name remains `community.window-switcher` so existing
installations can use this fork without changing their plugin settings.

## Using the switcher

Hold Alt and tap Tab to highlight your previous workspace. Keep holding Alt
and tap Tab again to move forward, or Shift+Tab to move backward. Release Alt
when the workspace you want is highlighted.

You can also left-click a preview or its workspace number to switch immediately,
including while holding Alt. Moving the pointer does not change selection.
Dragging the scrolling row cancels the click so you can still scroll it.

While the popup is open, ordinary
desktop shortcuts and mouse gestures are blocked to prevent them from acting
on windows behind it. The switcher's own shortcuts remain available, and normal
desktop controls return as soon as it closes.

While the switcher is open, Super+Backspace toggles its backdrop between the
configured transparency and an opaque theme background. This handles the usual
opacity shortcut inside the overlay. Outside the switcher, Omarchy's normal
window opacity command works as before. The backdrop choice lasts until the
plugin is reloaded.

## Appearance

Edit `compact.json` in the plugin directory to change the appearance. The default
settings are:

```json
{
  "thumbnailWidth": 800,
  "maxVisible": 5,
  "overflowMode": "wrap",
  "switchMode": "workspaces",
  "spacing": 28,
  "padding": 24,
  "cornerRadius": 0,
  "backgroundOpacity": 0.38,
  "showWallpaper": true
}
```

`thumbnailWidth` sets the preview width from 160 to 960 logical pixels before
the shell's interface scaling. Height follows the monitor's proportions.
Previews shrink when necessary to fit the available screen width or height.
`switchMode` chooses `"workspaces"` or `"windows"`. Missing or unrecognised
values use workspace mode. Save this setting between switching sessions; it
applies on the next opening. Your keyboard bindings stay the same in both modes.

`overflowMode` chooses how extra workspaces appear. Use `"wrap"` for stationary
previews that continue onto a second row, and further rows when needed. The
layout reduces preview size if the rows would otherwise exceed the screen.
Use `"scroll"` for the horizontal row with partial neighbouring previews.
An omitted or unrecognised value keeps the scrolling behaviour for compatibility.

`maxVisible` limits the number of complete previews per row. Smaller screens
fit fewer, or reduce preview size in wrapping mode. `spacing` controls the gap between
cards, `padding` controls the space around them, and `cornerRadius` sets how rounded
the preview borders are. `backgroundOpacity` controls how opaque the desktop
backdrop is, combined with the current theme's transparency. `showWallpaper`
controls the wallpaper inside previews. An unavailable or unsupported wallpaper
falls back to the theme background.

Changes to this file are loaded automatically. Omarchy may reload the plugin
when its files change, so save settings between switching sessions. To try a
different size while the switcher is open, run:

```bash
omarchy-shell shell call community.window-switcher setPreviewWidth 600
```

This command changes the size for the current plugin session. Save your preferred
width in `compact.json` to keep it after a restart.

## Architecture

The plugin runs inside Omarchy's existing Quickshell process. Rust calculates
workspace ordering and preview geometry, while native Quickshell components
capture window images and Qt Quick draws the overlay. See the
[architecture diagram and module guide](docs/architecture.md) for the complete flow.

## Updates and development

The Rust implementation is maintained on `main`. After updating, run
`./bin/build` in the plugin directory before restarting the shell. Rebuild after
a Qt upgrade as well. Build files are kept outside the plugin directory in
your user cache.

Save or commit your appearance changes before updating. The
[design notes](docs/design.md) explain updates, testing, compatibility limits
and how to restore an earlier version.

To run the code checks and layout tests from the repository, use:

```bash
./test/all
./test/presentation
```

Layout tests cover several screen sizes without opening a desktop window.
Checking real previews, keyboard behaviour and monitor focus still requires
testing the switcher in a running desktop session.

## Credits and license

Workspace Switcher is a focused fork of
[devmobasa/omarchy-window-switcher](https://github.com/devmobasa/omarchy-window-switcher).
It builds on the original workspace history, window information and preview
components. The original copyright and license notices are preserved in
[LICENSE](LICENSE).

The flat preview layout takes visual inspiration from
[Woogy7's workspace switcher](https://github.com/Woogy7/omarchy-workspace-switcher).
