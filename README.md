# Omarchy Workspace Switcher

A compact MRU workspace switcher for Omarchy. Hold Alt and press Tab to cycle
through occupied regular workspaces; release Alt to switch. Each card shows
the workspace's native window composition. Left-click a card to switch to it.

The strip follows the focused monitor, preserves preview aspect ratios, scrolls
to the selected card, and uses the current Omarchy theme. The supplied layer
rule disables the compositor fade; previews have no QML fade either.

## Install

Requires Omarchy's schema-version-1 plugin host, Quickshell with native
`ToplevelManager`/`ScreencopyView`, and Hyprland's toplevel export protocol for
previews.

For a new installation:

```bash
git clone --branch refactor/workspace-only https://github.com/clundstrom/omarchy-window-switcher.git \
  ~/.config/omarchy/plugins/community.window-switcher
omarchy plugin enable community.window-switcher
```

Add [docs/bindings.lua](docs/bindings.lua) to `~/.config/hypr/bindings.lua`, then:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

The plugin ID remains `community.window-switcher` for installed compatibility.
The bindings invoke the running plugin directly through Hyprland global
shortcuts. They do not launch a command on each keypress. These defaults replace
Omarchy's existing Alt+Tab window-navigation bindings with workspace switching.
Bindings refer to logical Alt; keyboard remapping can change the physical key.
For an Alt/Super-swapped setup, use `SUPER` in both cycling bindings and
`Super_L`/`Super_R` in the modifier trackers instead.

## Controls

| Input | Action |
|---|---|
| Alt+Tab | Open or cycle forward in MRU order |
| Alt+Shift+Tab | Open or cycle backward |
| Tab / Shift+Tab while open | Cycle forward / backward |
| Release Alt | Activate the selected workspace |
| Left-click a workspace card | Activate that workspace |

The order stays fixed while the switcher is open. Pointer movement does not
change the keyboard selection. Only occupied regular workspaces are listed.

## Appearance

Edit `compact.json` in the plugin directory. Dimensions are logical values
scaled with the shell's typography; panel width is also bounded by the monitor.

| Setting | Default | Range |
|---|---|---|
| `thumbnailWidth` | `264` | 160–400 |
| `maxVisible` | `5` | 1–8 cards |
| `spacing` | `12` | 4–32 |
| `padding` | `16` | 8–40 |
| `cornerRadius` | `16` | 0–32 |
| `backgroundOpacity` | `0.96` | 0.5–1, multiplying theme alpha |

## Development

```bash
PATH=/usr/lib/qt6/bin:$PATH ./test/all
./test/presentation
```

See [design, validation, updates and rollback](docs/design.md). To inspect the
running switcher:

```bash
omarchy-shell shell call community.window-switcher status ''
```

## License

MIT. Forked from [devmobasa/omarchy-window-switcher](https://github.com/devmobasa/omarchy-window-switcher).
Original copyright and license notices are retained in [LICENSE](LICENSE).
