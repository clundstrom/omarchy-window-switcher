import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons as Commons

// One application target, represented by its most recently used eligible window.
Item {
  id: card
  required property var groupData
  required property var windows
  required property var presentation
  required property bool selected
  required property bool interactive
  signal frameReady()
  signal activated(string workspaceKey)
  readonly property string iconSource: windows.length && windows[0].appIcon
    ? windows[0].appIcon : Quickshell.iconPath("application-x-executable")
  property bool useFallback: false
  onIconSourceChanged: useFallback = false

  Rectangle {
    anchors { top: parent.top; left: parent.left; right: parent.right; bottom: label.top }
    radius: Commons.Style.space(14)
    color: card.selected ? Commons.Util.alpha(Commons.Color.foreground, 0.1) : "transparent"
    border.width: card.selected ? Commons.Style.spacing.hairline : 0
    border.color: Commons.Color.accent
    IconImage {
      id: icon
      anchors.centerIn: parent
      implicitSize: Math.max(1, Math.min(card.presentation.appIconSize,
        parent.width - Commons.Style.space(24), parent.height - Commons.Style.space(24)))
      source: card.useFallback ? Quickshell.iconPath("application-x-executable") : card.iconSource
      asynchronous: true
      onStatusChanged: {
        if (status === Image.Ready) card.frameReady()
        else if (status === Image.Error) card.useFallback = true
      }
    }
  }
  Text {
    id: label
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: card.presentation.labelHeight
    text: card.groupData ? card.groupData.label : ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: Commons.Color.foreground
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
    opacity: card.selected ? 1 : 0
  }
  WorkspaceTapTarget {
    anchors.fill: parent
    enabled: card.interactive
    onActivated: if (card.groupData) card.activated(String(card.groupData.key))
  }
}
