import QtQuick

// Explicit selection belongs only to the app-window overview. Ordinary
// modifier-release switching keeps its existing input surface and shortcuts.
Item {
  id: surface
  property int columns: 1
  property int count: 0
  property int selectedIndex: -1
  signal selectionRequested(int index)
  signal committed()
  signal cancelled()
  Keys.priority: Keys.BeforeItem

  function move(dx, dy) {
    if (count <= 0) return
    var current = Math.max(0, Math.min(count - 1, selectedIndex))
    var cols = Math.max(1, columns)
    var row = Math.floor(current / cols)
    var targetRow = row + dy
    if (targetRow < 0 || targetRow > Math.floor((count - 1) / cols)) return
    var next = current + dx + dy * cols
    if (dx && (next < 0 || Math.floor(next / cols) !== row)) return
    next = Math.min(count - 1, next)
    if (next !== current) selectionRequested(next)
  }
  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
    if (event.key === Qt.Key_Left) move(-1, 0)
    else if (event.key === Qt.Key_Right) move(1, 0)
    else if (event.key === Qt.Key_Up) move(0, -1)
    else if (event.key === Qt.Key_Down) move(0, 1)
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (!event.isAutoRepeat) surface.committed()
    } else if (event.key === Qt.Key_Escape) {
      if (!event.isAutoRepeat) surface.cancelled()
    } else return
    event.accepted = true
  }
}
