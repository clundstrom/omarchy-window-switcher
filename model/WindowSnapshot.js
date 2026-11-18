// Preserve workspace capture delegates unless visible composition or source
// identity changes. Title, icon and focus-history metadata are not presentation
// inputs and must not rebuild an otherwise unchanged preview.

var RECORD_FIELDS = ["key", "workspaceId", "workspaceName", "monitorId", "monitorName", "minimized"]

function sameRect(left, right) {
  if (!left && !right) return true
  if (!left || !right) return false
  return left.x === right.x && left.y === right.y
    && left.width === right.width && left.height === right.height
}

function canReuse(current, candidate) {
  if (!current || !candidate || current.length !== candidate.length) return false
  for (var i = 0; i < current.length; i++) {
    var left = current[i]
    var right = candidate[i]
    if (!left || !right || left.toplevel !== right.toplevel) return false
    for (var fieldIndex = 0; fieldIndex < RECORD_FIELDS.length; fieldIndex++) {
      var field = RECORD_FIELDS[fieldIndex]
      if (left[field] !== right[field]) return false
    }
    if (!sameRect(left.rect, right.rect) || !sameRect(left.monitorRect, right.monitorRect))
      return false
  }
  return true
}

// This is the module interface. A false changed value means that callers must
// keep the returned record references to preserve the existing delegates.
function reconcile(current, candidate) {
  var existing = current || []
  var next = candidate || []
  if (canReuse(existing, next)) return { records: existing, changed: false }
  return { records: next, changed: true }
}

if (typeof module !== "undefined") {
  module.exports = {
    reconcile: reconcile
  }
}
