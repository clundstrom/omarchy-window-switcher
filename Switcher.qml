import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons
import "components"
import "native" as Native

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
  property string pendingActivationAddress: ""
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
  property bool opaqueBackground: false
  property double openedAt: 0
  property int firstFrameMs: -1
  property int openWorkMs: 0
  // Bounded memory-only diagnostics: no application text or persisted previews.
  property var lifecycleEvents: []
  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property var selectedWindow: selectedIndex >= 0 && selectedIndex < groups.length
    ? windows[groups[selectedIndex].startIndex] : null

  function noteLifecycle(event, key) {
    var entry = { event: event, time: Date.now() }
    if (key) entry.key = String(key).slice(0, 128)
    lifecycleEvents = lifecycleEvents.concat([entry]).slice(-16)
  }
  function currentToplevels() {
    try { return ToplevelManager.toplevels.values || [] } catch (error) { return [] }
  }
  function selectedKey() {
    return selectedIndex >= 0 && selectedIndex < groups.length ? groups[selectedIndex].key : ""
  }
  function coreCall(operation, input) {
    var result = JSON.parse(workspaceCore.evaluate(operation, JSON.stringify(input)))
    if (result && result.error) {
      console.warn("Workspace switcher: " + result.error)
      return null
    }
    return result
  }
  function metadata(record) {
    return { key: record.key, title: appearance.windowMode ? record.title : "",
      appId: appearance.windowMode ? record.appId : "", sourceToken: record.sourceToken, sourceIndex: record.sourceIndex,
      workspaceId: record.workspaceId, workspaceName: record.workspaceName,
      monitorId: record.monitorId, monitorName: record.monitorName, minimized: record.minimized,
      rect: record.rect, monitorRect: record.monitorRect }
  }
  function rebuildWindows(initialDirection) {
    var toplevels = currentToplevels()
    records.syncObjectKeys(toplevels)
    var rows = []
    var activeKey = null
    var active = ToplevelManager.activeToplevel
    for (var i = 0; i < toplevels.length; i++) {
      if (!toplevels[i]) continue
      var record = records.recordFor(toplevels[i], i)
      rows.push(record)
      if (record.toplevel === active) activeKey = record.key
    }
    var result = coreCall("refresh", { windowMode: appearance.windowMode, rows: rows.map(metadata), mruKeys: mruKeys,
      workspaceHistory: workspaceMruKeys, frozenHistory: openWorkspaceMruKeys,
      focusedWorkspaceId: Hyprland.focusedWorkspace ? focusedWorkspaceId : null,
      activeKey: activeKey, opened: opened,
      openingDirection: initialDirection === undefined ? null : initialDirection,
      previousWindows: windows.map(metadata), selectedKey: selectedKey(), selectedIndex: selectedIndex })
    if (!result) return
    mruKeys = result.mruKeys
    workspaceMruKeys = result.workspaceHistory
    allWindows = result.windowOrder.map(function(index) { return rows[index] })
    if (!opened) return
    openWorkspaceMruKeys = result.frozenHistory
    if (!result.changed) return
    windows = result.workspaceOrder.map(function(index) { return rows[index] })
    groups = result.groups
    selectedIndex = result.selectedIndex
    revealSelected()
  }
  function noteActiveToplevel() {
    var active = ToplevelManager.activeToplevel
    if (!active) return
    for (var i = 0; i < allWindows.length; i++) {
      var record = allWindows[i]
      if (record.toplevel !== active) continue
      var result = coreCall("focus", { mruKeys: mruKeys, workspaceHistory: workspaceMruKeys,
        liveKeys: allWindows.map(function(row) { return row.key }), key: record.key,
        workspaceId: record.workspaceId })
      if (result) {
        mruKeys = result.mruKeys
        workspaceMruKeys = result.workspaceHistory
      }
      break
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
    Qt.callLater(workspaceView.revealSelection)
  }
  function step(direction) {
    selectedIndex = workspaceCore.step(selectedIndex, direction, groups.length)
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
    pendingActivationAddress = ""
    targetScreen = targetScreenForOpen()
    releaseActivation = activateOnRelease
    releaseArmed = false
    captureLimit = 0
    openedAt = started
    firstFrameMs = -1
    opened = true
    appearance.prepareOpen()
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
  function beginClose(target, address) {
    if (!opened) return
    pendingActivation = target
    var hexAddress = String(address || "").replace(/^0x/, "")
    pendingActivationAddress = appearance.windowMode && /^[0-9a-fA-F]+$/.test(hexAddress)
      ? "0x" + hexAddress : ""
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
    beginClose(selected && selected.toplevel ? selected.toplevel : originalToplevel, selected ? selected.address : "")
  }
  function activateWorkspace(key) {
    if (!opened) return
    for (var i = 0; i < groups.length; i++) {
      if (String(groups[i].key) !== key) continue
      var target = windows[groups[i].startIndex]
      if (target && target.toplevel) {
        noteLifecycle("workspace-clicked", key)
        beginClose(target.toplevel, target.address)
      }
      return
    }
  }
  // Host lifecycle cleanup, independent of user-facing activation controls.
  function close() { beginClose(originalToplevel) }
  function toggleTransparency(unused) {
    if (!opened) return "ignored"
    opaqueBackground = !opaqueBackground
    return "handled"
  }
  function setPreviewWidth(value) {
    var width = Number(String(value).trim())
    if (!isFinite(width) || width <= 0) return "invalid width"
    var settings = JSON.parse(JSON.stringify(appearance.settings))
    settings.thumbnailWidth = Math.max(160, Math.min(960, width))
    appearance.settings = settings
    return String(settings.thumbnailWidth)
  }
  function ping() { return "ok" }
  function status() {
    var workspaceKeys = groups.map(function(group) { return String(group.id) })
      .filter(function(key, index, list) { return list.indexOf(key) === index })
    return JSON.stringify({ opened: opened, surfaceVisible: surfaceVisible,
      windowCount: allWindows.length, workspaceCount: workspaceKeys.length,
      switchMode: appearance.windowMode ? "windows" : "workspaces",
      itemCount: groups.length, itemKeys: groups.map(function(group) { return group.key }),
      selectedWindowKey: selectedWindow ? selectedWindow.key : "",
      workspaceKeys: workspaceKeys,
      workspaceHistory: openWorkspaceMruKeys, liveWorkspaceHistory: workspaceMruKeys,
      selectedIndex: selectedIndex, selectedWorkspaceId: selectedWindow ? selectedWindow.workspaceId : null,
      focusedWorkspaceId: focusedWorkspaceId, targetScreen: targetScreen ? targetScreen.name : "",
      captureLimit: captureLimit, captureBudget: captureBudget, openWorkMs: openWorkMs, firstFrameMs: firstFrameMs,
      keyFocus: keySurface.activeFocus, releaseArmed: releaseArmed, releaseActivation: releaseActivation,
      shortcutsInhibited: gestureGuard.active, backgroundOpaque: opaqueBackground,
      overflowMode: appearance.wrapOverflow ? "wrap" : "scroll",
      previewWidth: appearance.thumbnailWidth, wallpaperReady: appearance.wallpaperPreload.status === Image.Ready,
      modifierTrackingSeen: modifierTrackingSeen, globalModifierHeld: leftModifier.pressed || rightModifier.pressed,
      lifecycleEvents: lifecycleEvents })
  }

  Native.WorkspaceCore { id: workspaceCore }
  WorkspacePresentation {
    id: appearance
    onWindowModeChanged: if (root.opened) root.close()
  }
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
      var history = root.coreCall("workspaceFocus", { keys: root.workspaceMruKeys, workspaceId: workspaceId })
      if (history) root.workspaceMruKeys = history
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
      var address = root.pendingActivationAddress
      var serial = root.openSerial
      root.surfaceVisible = false
      root.windows = []
      root.groups = []
      root.originalToplevel = null
      root.pendingActivation = null
      root.pendingActivationAddress = ""
      root.targetScreen = null
      noteLifecycle("hidden")
      Qt.callLater(function() {
        if (serial !== root.openSerial || root.opened || !target) return
        // The foreign-toplevel path simulates pointer motion after activation.
        // Explicit window focus preserves selection with focus-follows-mouse.
        if (address) Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })')
        else target.activate()
      })
    }
  }
  Timer { id: modelRefresh; interval: 24; onTriggered: root.rebuildWindows() }
  Timer { id: geometrySettle; interval: 160; onTriggered: root.geometryReady() }
  Timer {
    id: captureRamp
    interval: 16
    repeat: true
    // Start the first batch once geometry is ready, then pace later batches.
    triggeredOnStart: true
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
    // Desktop mouse bindings are processed before QML pointer events. Keep
    // gestures such as Super+right-drag out of this workspace overlay.
    // Its four native bindings bypass inhibition; all gestures resume on close.
    ShortcutInhibitor {
      id: gestureGuard
      window: panel
      enabled: root.opened
    }
    mask: Region { width: root.opened ? panel.width : 0; height: root.opened ? panel.height : 0 }
    SwitcherKeySurface {
      id: keySurface
      anchors.fill: parent
      releaseArmed: root.releaseArmed
      releaseActivation: root.releaseActivation
      onStepped: function(direction) { root.step(direction) }
      onModifierReleased: root.finishModifierRelease()
      onTransparencyToggled: root.toggleTransparency("")
      Rectangle {
        anchors.fill: parent
        color: Commons.Util.alpha(Commons.Color.background,
          root.opaqueBackground ? 1 : appearance.backgroundOpacity * Commons.Color.background.a)
      }
      Rectangle {
        id: strip
        anchors.centerIn: parent
        readonly property var rowMetrics: appearance.layoutMetricsFor(
          parent.width - Commons.Style.space(48) - appearance.padding * 2, root.windows,
          parent.height - Commons.Style.space(48) - appearance.padding * 2, root.groups.length)
        width: rowMetrics.viewportWidth + appearance.padding * 2
        height: rowMetrics.viewportHeight + appearance.padding * 2
        radius: appearance.cornerRadius
        color: "transparent"
        WorkspaceGridView {
          id: workspaceView
          anchors.fill: parent
          anchors.margins: appearance.padding
          workspaceGroups: root.groups
          windows: root.windows
          metrics: strip.rowMetrics
          presentation: appearance
          selectedIndex: root.selectedIndex
          switcherOpen: root.opened
          captureLimit: root.captureLimit
          onWorkspaceActivated: function(workspaceKey) { root.activateWorkspace(workspaceKey) }
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
