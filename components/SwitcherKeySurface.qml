import QtQuick

// Only the workspace-switching keys. Modifier release is also tracked by
// native global shortcuts so a release before layer focus cannot get lost.
Item {
  id: surface
  required property bool releaseArmed
  required property bool releaseActivation
  signal cancelled()
  signal committed()
  signal stepped(int direction)
  signal modifierReleased()
  focus: true
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) surface.cancelled()
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) surface.committed()
    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
      surface.stepped(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1)
    else return
    event.accepted = true
  }
  Keys.onReleased: function(event) {
    if (!surface.releaseActivation || !surface.releaseArmed) return
    if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr
        || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
      surface.modifierReleased()
      event.accepted = true
    }
  }
}
