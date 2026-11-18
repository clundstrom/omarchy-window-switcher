import QtQuick
import Quickshell
import Quickshell.Hyprland

// Non-visual record builder: turns compositor toplevels into the plain
// records the model functions operate on.
QtObject {
  id: records

  property var objectKeyRows: []
  property int nextObjectKey: 1
  readonly property string objectKeyPrefix: "object:"
  readonly property string hyprlandKeyPrefix: "hyprland:"

  function hyprlandToplevelFor(toplevel) {
    var values = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < values.length; i++) {
      if (values[i] && values[i].wayland === toplevel) return values[i]
    }
    return null
  }

  function syncObjectKeys(toplevels) {
    var next = []
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var existingKey = ""
      for (var j = 0; j < objectKeyRows.length; j++) {
        if (objectKeyRows[j].toplevel === toplevel) {
          existingKey = objectKeyRows[j].key
          break
        }
      }
      if (!existingKey) existingKey = objectKeyPrefix + nextObjectKey++
      next.push({ toplevel: toplevel, key: existingKey })
    }
    objectKeyRows = next
  }

  function fallbackKeyFor(toplevel) {
    for (var i = 0; i < objectKeyRows.length; i++) {
      if (objectKeyRows[i].toplevel === toplevel) return objectKeyRows[i].key
    }
    return ""
  }

  function monitorRectFor(monitor) {
    if (!monitor) return null
    var ipc = monitor.lastIpcObject || {}
    var scale = Number(monitor.scale !== undefined ? monitor.scale : ipc.scale)
    if (!isFinite(scale) || scale <= 0) scale = 1
    var width = Number(monitor.width !== undefined ? monitor.width : ipc.width) || 0
    var height = Number(monitor.height !== undefined ? monitor.height : ipc.height) || 0
    if (ipc.transform !== undefined && Number(ipc.transform) % 2 === 1) {
      var swap = width
      width = height
      height = swap
    }
    if (!width || !height) return null
    return {
      x: Number(monitor.x !== undefined ? monitor.x : ipc.x) || 0,
      y: Number(monitor.y !== undefined ? monitor.y : ipc.y) || 0,
      width: width / scale,
      height: height / scale
    }
  }

  // Quickshell exposes coordinate pairs as indexed Qt lists, not JS Arrays.
  function geometryPair(value) {
    if (!value || typeof value !== "object" || typeof value.length !== "number" || value.length < 2
        || value[0] === null || value[0] === undefined || value[1] === null || value[1] === undefined) return null
    var first = Number(value[0])
    var second = Number(value[1])
    return isFinite(first) && isFinite(second) ? [first, second] : null
  }
  function recordFor(toplevel, sourceIndex) {
    var hyprland = hyprlandToplevelFor(toplevel)
    var ipc = hyprland && hyprland.lastIpcObject ? hyprland.lastIpcObject : {}
    var at = geometryPair(ipc.at)
    var ipcSize = geometryPair(ipc.size)
    var workspace = hyprland ? hyprland.workspace : null
    var monitor = hyprland ? hyprland.monitor : null
    var address = String(hyprland && hyprland.address ? hyprland.address : "")
    var workspaceId = workspace ? workspace.id : null
    var workspaceName = workspace ? String(workspace.name || workspace.id || "") : ""
    var monitorId = monitor ? monitor.id : null
    var monitorName = monitor ? String(monitor.name || "") : ""
    var focusHistoryId = Number(ipc.focusHistoryID)
    if (!isFinite(focusHistoryId) || focusHistoryId < 0) focusHistoryId = sourceIndex
    var record = {
      title: boundedLabel(toplevel && toplevel.title, 512),
      appId: boundedLabel(toplevel && toplevel.appId, 256),
      key: address ? hyprlandKeyPrefix + address : fallbackKeyFor(toplevel),
      sourceIndex: focusHistoryId,
      sourceToken: fallbackKeyFor(toplevel),
      toplevel: toplevel,
      address: address,
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      monitorId: monitorId,
      monitorName: monitorName,
      rect: at && ipcSize ? {
        x: Number(at[0]) || 0,
        y: Number(at[1]) || 0,
        width: Number(ipcSize[0]) || 0,
        height: Number(ipcSize[1]) || 0
      } : null,
      monitorRect: monitorRectFor(monitor),
      minimized: toplevel && toplevel.minimized === true
    }
    return record
  }

  function boundedLabel(value, limit) {
    var text = String(value || "").slice(0, limit)
    // Keep a truncated UTF-16 surrogate pair valid for the Rust JSON boundary.
    var last = text.charCodeAt(text.length - 1)
    return last >= 0xd800 && last <= 0xdbff ? text.slice(0, -1) : text
  }

}
