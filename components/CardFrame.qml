import QtQuick
import qs.Commons

// Shared selection shell for every window-bearing card. Keeping opacity,
// scale, stacking, ring, and border here makes the two card views hand off
// selection atomically and prevents their visual hierarchy from drifting.
Item {
  id: frame

  required property bool selected
  property bool compact: false
  property int compactRadius: Style.space(10)
  property bool showSelectedControl: true
  property Component selectedControl: null
  default property alias contentData: surface.data
  readonly property int contentInset: surface.border.width

  opacity: compact ? 1 : (selected ? 1 : 0.7)
  scale: compact ? 1 : (selected ? 1.04 : 1)
  z: selected ? 2 : 1

  Rectangle {
    anchors.fill: surface
    anchors.margins: -Style.space(3)
    visible: frame.selected && !frame.compact
    radius: surface.radius > 0 ? surface.radius + Style.space(3) : 0
    color: "transparent"
    border.width: Math.max(1, Style.spacing.hairline)
    border.color: Util.alpha(Color.accent, 0.35)
    z: -1
  }

  Rectangle {
    id: surface

    anchors.fill: parent
    color: frame.compact
      ? (frame.selected ? Util.alpha(Color.accent, 0.09) : "transparent")
      : (frame.selected ? Color.menu.selectedBackground : Color.menu.background)
    radius: frame.compact ? frame.compactRadius : Style.cornerRadius
    border.width: frame.compact ? 1 : (frame.selected ? Math.max(3, Style.spacing.hairline * 3) : Style.spacing.hairline)
    border.color: frame.selected ? Color.accent : (frame.compact ? "transparent" : Color.menu.border)
    clip: true
  }

  Loader {
    id: selectedControlLoader

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.spacing.md
    sourceComponent: frame.selectedControl
    visible: frame.selected && frame.showSelectedControl
    z: 100
  }
}
