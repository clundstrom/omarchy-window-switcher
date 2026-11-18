import QtQuick

// Workspace switching and the standard opacity shortcut. Modifier release is tracked by
// native global shortcuts so a release before layer focus cannot get lost.
Item {
  id: surface
  required property bool releaseArmed
  required property bool releaseActivation
  signal stepped(int direction)
  signal modifierReleased()
  signal transparencyToggled()
  focus: true
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
      surface.stepped(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1)
    else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.MetaModifier)
        && !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) {
      if (!event.isAutoRepeat) surface.transparencyToggled()
    } else return
    event.accepted = true
  }
  function handleModifierRelease(event) {
    if (!surface.releaseActivation || !surface.releaseArmed) return
    if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr
        || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
      const altKey = event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr
      const otherHeld = altKey ? (event.modifiers & Qt.MetaModifier) : (event.modifiers & Qt.AltModifier)
      if (otherHeld) { event.accepted = true; return }
      surface.modifierReleased()
      event.accepted = true
    }
  }
  Keys.onReleased: function(event) { surface.handleModifierRelease(event) }
}
