import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Compositor event wiring: which Hyprland and Wayland signals matter to the
// switcher and how urgently they invalidate its state.
Item {
  id: compositor

  required property bool switcherOpen
  property bool windowMode: false

  signal refreshRequested()
  signal geometryRefreshRequested()
  signal geometrySnapshotReceived()
  signal activeWindowChanged()
  signal workspaceFocusChanged(var workspaceId)
  signal screenLayoutChanged()

  readonly property var geometryEventNames: [
    "openwindow", "closewindow", "movewindow", "movewindowv2", "minimize", "fullscreen",
    "workspace", "workspacev2", "focusedmon", "moveworkspace", "moveworkspacev2"
  ]
  readonly property var refreshEventNames: geometryEventNames.concat([
    "activewindow", "activewindowv2"
  ]).concat(windowMode ? ["windowtitle", "windowtitlev2"] : [])

  visible: false

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { compositor.refreshRequested() }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { compositor.activeWindowChanged() }
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() { compositor.refreshRequested() }
  }

  // In the installed Quickshell, each client snapshot updates its address
  // signal even if its value is unchanged. Queue the notification until the
  // whole reply is applied. The controller retains its settle-timer fallback
  // for versions that do not emit this signal on an unchanged address.
  Connections {
    target: Hyprland.toplevels && Hyprland.toplevels.values.length > 0
      ? Hyprland.toplevels.values[0] : null
    function onAddressChanged() {
      if (compositor.switcherOpen) Qt.callLater(function() { compositor.geometrySnapshotReceived() })
    }
  }

  Connections {
    target: Hyprland
    function onFocusedMonitorChanged() { compositor.screenLayoutChanged() }
    function onFocusedWorkspaceChanged() {
      var workspace = Hyprland.focusedWorkspace
      compositor.workspaceFocusChanged(workspace ? workspace.id : null)
      compositor.refreshRequested()
    }
    function onRawEvent(event) {
      if (!event) return
      var name = String(event.name || "")
      if (compositor.refreshEventNames.indexOf(name) < 0) return
      compositor.refreshRequested()

      // Layout-changing events also invalidate the IPC geometry snapshot the
      // workspace miniatures are drawn from; re-request it while open.
      if (compositor.switcherOpen && compositor.geometryEventNames.indexOf(name) >= 0) {
        Hyprland.refreshToplevels()
        compositor.geometryRefreshRequested()
      }
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() { compositor.screenLayoutChanged() }
  }

}
