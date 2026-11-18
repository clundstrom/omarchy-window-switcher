import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons
import "components"
import "model/WorkspaceModel.js" as WorkspaceModel
import "model/WindowSnapshot.js" as WindowSnapshot
import "model/MruOrder.js" as MruOrder
import "model/Navigation.js" as Navigation

Item {
  id: root
  // Plugin host injection; the workspace switcher does not require shell internals.
  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool surfaceVisible: false
  property var targetScreen: null
  property var originalToplevel: null
  property var pendingActivation: null
  property var allWindows: []
  property var windows: []
  property var groups: []
  property var mruKeys: []
  property var workspaceMruKeys: []
  property var openWorkspaceMruKeys: []
  property int selectedIndex: -1
  property int captureLimit: 0
  readonly property int captureBudget: 20
  property int openSerial: 0
  property bool releaseArmed: false
  property bool releaseActivation: true
  property bool modifierTrackingSeen: false
  property double openedAt: 0
  property int firstFrameMs: -1
  property int openWorkMs: 0
  // Bounded memory-only diagnostics: no application text or persisted previews.
  property var lifecycleEvents: []
  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property var selectedWindow: selectedIndex >= 0 && selectedIndex < groups.length
    ? windows[groups[selectedIndex].startIndex] : null

  function noteLifecycle(event) {
    lifecycleEvents = lifecycleEvents.concat([{ event: event, time: Date.now() }]).slice(-16)
  }
  function currentToplevels() {
    try { return ToplevelManager.toplevels.values || [] } catch (error) { return [] }
  }
  function selectedKey() {
    return selectedIndex >= 0 && selectedIndex < groups.length ? groups[selectedIndex].key : ""
  }
  function groupIndex(key) {
    for (var i = 0; i < groups.length; i++) if (groups[i].key === String(key)) return i
    return -1
  }
  function rebuildWindows(initialDirection) {
    var previousKey = selectedKey()
    var previousIndex = selectedIndex
    var toplevels = currentToplevels()
    records.syncObjectKeys(toplevels)
    var rows = []
    for (var i = 0; i < toplevels.length; i++) {
      if (toplevels[i]) rows.push(records.recordFor(toplevels[i], i))
    }
    mruKeys = MruOrder.pruneMru(mruKeys, rows, 200)
    var active = ToplevelManager.activeToplevel
    for (var j = 0; active && j < rows.length; j++) {
      if (rows[j].toplevel === active) {
        mruKeys = MruOrder.noteMru(mruKeys, rows[j].key, rows, 200)
        break
      }
    }
    allWindows = MruOrder.orderByMru(rows, mruKeys)
    workspaceMruKeys = WorkspaceModel.completeWorkspaceMru(workspaceMruKeys, allWindows,
      Hyprland.focusedWorkspace ? focusedWorkspaceId : null, 100)
    if (!opened) return
    if (initialDirection !== undefined) openWorkspaceMruKeys = workspaceMruKeys.slice()
    var next = WorkspaceModel.orderByWorkspace(WorkspaceModel.regularWindows(allWindows), openWorkspaceMruKeys)
    if (initialDirection === undefined) {
      var snapshot = WindowSnapshot.reconcile(windows, next)
      if (!snapshot.changed) return
      next = snapshot.records
    }
    windows = next
    groups = WorkspaceModel.groupWindows(next)
    var preserved = groupIndex(previousKey)
    if (!groups.length) selectedIndex = -1
    else if (initialDirection !== undefined) {
      if (initialDirection < 0) {
        var current = groupIndex(String(focusedWorkspaceId))
        selectedIndex = Navigation.moveSequential(current >= 0 ? current : 0, -1, groups.length)
      } else {
        var key = initialDirection === 0 ? String(focusedWorkspaceId)
          : WorkspaceModel.previousWorkspaceKey(next, focusedWorkspaceId, openWorkspaceMruKeys)
        selectedIndex = Math.max(0, groupIndex(key))
      }
    } else selectedIndex = preserved >= 0 ? preserved : Math.max(0, Math.min(previousIndex, groups.length - 1))
    revealSelected()
  }
  function noteActiveToplevel() {
    var active = ToplevelManager.activeToplevel
    if (!active) return
    for (var i = 0; i < allWindows.length; i++) {
      var record = allWindows[i]
      if (record.toplevel === active) {
        mruKeys = MruOrder.noteMru(mruKeys, record.key, allWindows, 200)
        workspaceMruKeys = WorkspaceModel.noteWorkspaceMru(workspaceMruKeys, record.workspaceId, 100)
        break
      }
    }
    modelRefresh.restart()
  }
  function targetScreenForOpen() {
    var screens = Quickshell.screens || []
    var focused = Hyprland.focusedMonitor
    for (var i = 0; i < screens.length; i++) {
      var monitor = Hyprland.monitorFor(screens[i])
      if (focused && (monitor === focused || (monitor && monitor.id === focused.id)
          || String(screens[i].name || "") === String(focused.name || ""))) return screens[i]
    }
    var active = ToplevelManager.activeToplevel
    if (active && active.screens && active.screens.length) return active.screens[0]
    return screens.length ? screens[0] : null
  }
  function revealSelected() {
    Qt.callLater(function() {
      if (!root.opened || root.selectedIndex < 0) return
      workspaceView.forceLayout()
      workspaceView.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }
  function step(direction) {
    selectedIndex = Navigation.moveSequential(selectedIndex, direction, groups.length)
    revealSelected()
  }
  function finishModifierRelease() {
    if (opened && releaseActivation && !leftModifier.pressed && !rightModifier.pressed) {
      noteLifecycle("modifier-released")
      commitSelected()
    }
  }
  function beginCaptureRamp() {
    captureRamp.stop()
    captureLimit = 0
    if (opened && windows.length) captureRamp.start()
  }
  function geometryReady() {
    if (!opened) return
    geometrySettle.stop()
    rebuildWindows()
    if (!captureLimit) beginCaptureRamp()
    noteLifecycle("geometry-ready")
  }
  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") || ({}) } catch (error) {}
    openWorkspace(Number(payload.direction) < 0 ? -1 : (Number(payload.direction) === 0 ? 0 : 1), payload.activation !== "explicit")
  }
  function openWorkspace(direction, activateOnRelease) {
    if (opened) {
      if (direction) step(direction)
      return
    }
    var started = Date.now()
    openSerial++
    closeTick.stop()
    originalToplevel = ToplevelManager.activeToplevel
    pendingActivation = null
    targetScreen = targetScreenForOpen()
    releaseActivation = activateOnRelease
    releaseArmed = false
    captureLimit = 0
    openedAt = started
    firstFrameMs = -1
    opened = true
    rebuildWindows(direction)
    surfaceVisible = true
    Hyprland.refreshToplevels()
    Hyprland.refreshMonitors()
    geometrySettle.restart()
    focusDelay.restart()
    openWorkMs = Date.now() - started
    noteLifecycle("opened")
    Qt.callLater(function() {
      if (root.opened && root.modifierTrackingSeen) root.finishModifierRelease()
    })
  }
  function beginClose(target) {
    if (!opened) return
    pendingActivation = target
    opened = false
    releaseArmed = false
    captureRamp.stop()
    geometrySettle.stop()
    captureLimit = 0
    noteLifecycle("closing")
    closeTick.restart()
  }
  function commitSelected() {
    var selected = selectedWindow
    beginClose(selected && selected.toplevel ? selected.toplevel : originalToplevel)
  }
  function cancel() { beginClose(originalToplevel) }
  function close() { cancel() }
  function ping() { return "ok" }
  function status() {
    return JSON.stringify({ opened: opened, surfaceVisible: surfaceVisible,
      windowCount: allWindows.length, workspaceCount: groups.length,
      workspaceKeys: groups.map(function(group) { return group.key }),
      workspaceHistory: openWorkspaceMruKeys, liveWorkspaceHistory: workspaceMruKeys,
      selectedIndex: selectedIndex, selectedWorkspaceId: selectedWindow ? selectedWindow.workspaceId : null,
      focusedWorkspaceId: focusedWorkspaceId, targetScreen: targetScreen ? targetScreen.name : "",
      captureLimit: captureLimit, captureBudget: captureBudget, openWorkMs: openWorkMs, firstFrameMs: firstFrameMs,
      keyFocus: keySurface.activeFocus, releaseArmed: releaseArmed, releaseActivation: releaseActivation,
      modifierTrackingSeen: modifierTrackingSeen, globalModifierHeld: leftModifier.pressed || rightModifier.pressed,
      lifecycleEvents: lifecycleEvents })
  }

  WorkspacePresentation { id: appearance }
  WindowRecords { id: records }
  GlobalShortcut {
    appid: "community.window-switcher"
    name: "next-workspace"
    description: "Next recent workspace"
    onPressed: { root.noteLifecycle("invoked"); root.openWorkspace(1, true) }
  }
  GlobalShortcut {
    appid: "community.window-switcher"
    name: "previous-workspace"
    description: "Previous recent workspace"
    onPressed: { root.noteLifecycle("invoked"); root.openWorkspace(-1, true) }
  }
  GlobalShortcut {
    id: leftModifier
    appid: "community.window-switcher"
    name: "modifier-left"
    description: "Workspace switcher left modifier state"
    onPressed: { root.modifierTrackingSeen = true; root.noteLifecycle("modifier-pressed") }
    onReleased: root.finishModifierRelease()
  }
  GlobalShortcut {
    id: rightModifier
    appid: "community.window-switcher"
    name: "modifier-right"
    description: "Workspace switcher right modifier state"
    onPressed: { root.modifierTrackingSeen = true; root.noteLifecycle("modifier-pressed") }
    onReleased: root.finishModifierRelease()
  }
  CompositorSignals {
    switcherOpen: root.opened
    onRefreshRequested: modelRefresh.restart()
    onGeometryRefreshRequested: geometrySettle.restart()
    onGeometrySnapshotReceived: if (geometrySettle.running) root.geometryReady()
    onActiveWindowChanged: root.noteActiveToplevel()
    onWorkspaceFocusChanged: function(workspaceId) {
      root.workspaceMruKeys = WorkspaceModel.noteWorkspaceMru(root.workspaceMruKeys, workspaceId, 100)
    }
    onScreenLayoutChanged: {
      if (root.opened) root.targetScreen = root.targetScreenForOpen()
      modelRefresh.restart()
    }
  }
  Timer {
    id: focusDelay
    interval: 1
    onTriggered: {
      if (!root.opened) return
      keySurface.forceActiveFocus()
      root.releaseArmed = true
    }
  }
  Timer {
    id: closeTick
    interval: 1
    onTriggered: {
      if (root.opened) return
      var target = root.pendingActivation
      var serial = root.openSerial
      root.surfaceVisible = false
      root.windows = []
      root.groups = []
      root.originalToplevel = null
      root.pendingActivation = null
      root.targetScreen = null
      noteLifecycle("hidden")
      Qt.callLater(function() { if (serial === root.openSerial && !root.opened && target) target.activate() })
    }
  }
  Timer { id: modelRefresh; interval: 24; onTriggered: root.rebuildWindows() }
  Timer { id: geometrySettle; interval: 160; onTriggered: root.geometryReady() }
  Timer {
    id: captureRamp
    interval: 16
    repeat: true
    onTriggered: {
      if (!root.opened) { stop(); return }
      var target = Math.min(root.captureBudget, root.windows.length)
      root.captureLimit = Math.min(target, root.captureLimit + 2)
      if (root.captureLimit >= target) stop()
    }
  }
  Component.onCompleted: rebuildWindows()

  PanelWindow {
    id: panel
    screen: root.targetScreen
    visible: root.surfaceVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { width: root.opened ? panel.width : 0; height: root.opened ? panel.height : 0 }
    MouseArea { anchors.fill: parent; enabled: root.opened; onClicked: root.cancel() }
    SwitcherKeySurface {
      id: keySurface
      anchors.fill: parent
      releaseArmed: root.releaseArmed
      releaseActivation: root.releaseActivation
      onCancelled: root.cancel()
      onCommitted: root.commitSelected()
      onStepped: function(direction) { root.step(direction) }
      onModifierReleased: root.commitSelected()
      Rectangle {
        id: strip
        anchors.centerIn: parent
        width: Math.min(parent.width - Commons.Style.space(48),
          Math.max(1, Math.min(appearance.maxVisible, root.groups.length))
            * (appearance.thumbnailWidth + appearance.spacing) + appearance.padding * 2)
        height: workspaceView.metrics.cardHeight + appearance.padding * 2
        radius: appearance.cornerRadius
        color: Commons.Util.alpha(Commons.Color.menu.background, Commons.Color.menu.background.a * appearance.backgroundOpacity)
        border.width: 1
        border.color: Commons.Util.alpha(Commons.Color.menu.border, 0.28)
        MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true } }
        WorkspaceGridView {
          id: workspaceView
          anchors.fill: parent
          anchors.margins: appearance.padding
          workspaceGroups: root.groups
          windows: root.windows
          metrics: appearance.metricsFor(width, root.windows)
          presentation: appearance
          selectedIndex: root.selectedIndex
          switcherOpen: root.opened
          captureLimit: root.captureLimit
          onCardActivated: function(index) {
            root.selectedIndex = index
            root.commitSelected()
          }
          onFrameReady: {
            if (root.opened && root.firstFrameMs < 0) {
              root.firstFrameMs = Date.now() - root.openedAt
              root.noteLifecycle("first-frame")
            }
          }
        }
      }
    }
  }
}
