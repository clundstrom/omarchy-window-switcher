import QtQuick

// Passive until release, so dragging the scrolling layout cancels the tap.
Item {
  id: surface
  signal activated()
  TapHandler {
    acceptedButtons: Qt.LeftButton
    gesturePolicy: TapHandler.DragThreshold
    onTapped: surface.activated()
  }
}
