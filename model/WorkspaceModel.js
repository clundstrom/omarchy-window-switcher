// Workspace history and preview geometry retained from the original model.

function stringValue(value) { return value === undefined || value === null ? "" : String(value) }

// Hyprland IPC arrays arrive in QML as QVariantList proxies: indexed and
// length-bearing, but not JavaScript Arrays. Keep this check independent of
// Array.isArray so native compositor geometry is not discarded.
function geometryPair(value) {
  if (!value || typeof value !== "object" || typeof value.length !== "number" || value.length < 2
      || value[0] === null || value[0] === undefined
      || value[1] === null || value[1] === undefined) return null
  var first = Number(value[0])
  var second = Number(value[1])
  return isFinite(first) && isFinite(second) ? [first, second] : null
}

function normalizedRect(rect, monitorRect) {
  if (!rect || !monitorRect) return null
  var monitorWidth = Number(monitorRect.width)
  var monitorHeight = Number(monitorRect.height)
  if (!(monitorWidth > 0) || !(monitorHeight > 0)
      || !isFinite(monitorWidth) || !isFinite(monitorHeight)) return null
  var width = Number(rect.width) / monitorWidth
  var height = Number(rect.height) / monitorHeight
  if (!(width > 0) || !(height > 0) || !isFinite(width) || !isFinite(height)) return null
  var x = (Number(rect.x) - (Number(monitorRect.x) || 0)) / monitorWidth
  var y = (Number(rect.y) - (Number(monitorRect.y) || 0)) / monitorHeight
  if (!isFinite(x) || !isFinite(y)) return null
  // Scrolling and floating windows may extend beyond the monitor. Preserve
  // their native position and dimensions; clip the workspace canvas instead
  // of moving/resizing each miniature to fit it.
  return { x: x, y: y, width: width, height: height }
}

function workspaceLayout(windows) {
  var values = windows || []
  var result = []
  var visible = []
  var spatialCount = 0

  for (var i = 0; i < values.length; i++) {
    var record = values[i]
    var hidden = !record || record.minimized === true
    result.push({ hidden: hidden, x: 0, y: 0, width: 0, height: 0 })
    if (hidden) continue
    visible.push(i)
    var rect = normalizedRect(record.rect, record.monitorRect)
    if (rect) {
      spatialCount++
      result[i].x = rect.x
      result[i].y = rect.y
      result[i].width = rect.width
      result[i].height = rect.height
    } else result[i].hidden = true
  }
  // One incomplete/stale record must not rearrange every valid window into
  // a guessed grid. A missing miniature appears when its geometry arrives.
  if (spatialCount > 0 || visible.length === 0) return result

  var columns = Math.ceil(Math.sqrt(visible.length))
  var rows = Math.ceil(visible.length / columns)
  var inset = 0.03
  for (var j = 0; j < visible.length; j++) {
    var cell = result[visible[j]]
    cell.hidden = false
    cell.x = (j % columns) / columns + inset
    cell.y = Math.floor(j / columns) / rows + inset
    cell.width = 1 / columns - inset * 2
    cell.height = 1 / rows - inset * 2
  }
  return result
}

function noteWorkspaceMru(keys, workspaceId, limit) {
  var values = keys || []
  var key = workspaceId === undefined || workspaceId === null
    ? "" : stringValue(workspaceId).trim()
  var maximum = Math.max(1, Number(limit) || 100)
  if (!key) return values.slice(0, maximum)
  var result = [key]
  for (var i = 0; i < values.length && result.length < maximum; i++) {
    var existing = stringValue(values[i]).trim()
    if (existing && existing !== key && result.indexOf(existing) < 0) result.push(existing)
  }
  return result
}

function completeWorkspaceMru(keys, records, focusedWorkspaceId, limit) {
  var maximum = Math.max(1, Number(limit) || 100)
  var result = noteWorkspaceMru(keys, focusedWorkspaceId, maximum)
  var values = records || []
  for (var i = 0; i < values.length && result.length < maximum; i++) {
    var record = values[i]
    if (!record || record.workspaceId === undefined || record.workspaceId === null) continue
    var key = String(record.workspaceId)
    if (result.indexOf(key) < 0) result.push(key)
  }
  return result
}

function previousWorkspaceKey(records, focusedWorkspaceId, recentWorkspaceKeys) {
  var values = records || []
  var recent = recentWorkspaceKeys || []
  for (var recentIndex = 0; recentIndex < recent.length; recentIndex++) {
    var recentKey = stringValue(recent[recentIndex])
    if (!recentKey || Number(recentKey) === Number(focusedWorkspaceId)) continue
    for (var recordIndex = 0; recordIndex < values.length; recordIndex++) {
      var candidate = values[recordIndex]
      if (candidate && candidate.workspaceId !== undefined && candidate.workspaceId !== null
          && String(candidate.workspaceId) === recentKey)
        return recentKey
    }
  }
  for (var i = 0; i < values.length; i++) {
    var record = values[i]
    if (!record || record.workspaceId === undefined || record.workspaceId === null) continue
    if (Number(record.workspaceId) !== Number(focusedWorkspaceId)) return String(record.workspaceId)
  }
  return ""
}

function regularWindows(records) {
  return (records || []).filter(function(record) {
    return record && !record.minimized && Number(record.workspaceId) > 0
      && String(record.workspaceName || "").indexOf("special:") !== 0
  })
}

function orderByWorkspace(records, history) {
  return (records || []).map(function(record, index) { return { record: record, index: index } })
    .sort(function(left, right) {
      var a = history.indexOf(String(left.record.workspaceId))
      var b = history.indexOf(String(right.record.workspaceId))
      if (a < 0) a = history.length
      if (b < 0) b = history.length
      return a - b || Number(left.record.workspaceId) - Number(right.record.workspaceId) || left.index - right.index
    }).map(function(entry) { return entry.record })
}

function groupWindows(records) {
  var groups = []
  for (var i = 0; i < records.length; i++) {
    var record = records[i]
    var key = String(record.workspaceId)
    var group = groups.length ? groups[groups.length - 1] : null
    if (!group || group.key !== key) {
      group = { key: key, id: record.workspaceId, label: "Workspace " + (record.workspaceName || key), startIndex: i, size: 0 }
      groups.push(group)
    }
    group.size++
  }
  return groups
}


if (typeof module !== "undefined") module.exports = {
  geometryPair: geometryPair,
  normalizedRect: normalizedRect,
  workspaceLayout: workspaceLayout,
  noteWorkspaceMru: noteWorkspaceMru,
  completeWorkspaceMru: completeWorkspaceMru,
  previousWorkspaceKey: previousWorkspaceKey,
  regularWindows: regularWindows,
  orderByWorkspace: orderByWorkspace,
  groupWindows: groupWindows
}
