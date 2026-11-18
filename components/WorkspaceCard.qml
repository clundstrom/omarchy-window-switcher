import QtQuick
import Quickshell.Wayland
import qs.Commons as Commons
import "../native" as Native

// The original native workspace composition, with one label and one border.
Rectangle {
  id: card
  required property var groupData
  required property var windows
  required property var presentation
  required property bool selected
  required property bool captureEnabled
  required property int captureStart
  required property int captureLimit
  signal frameReady()

  Native.WorkspaceCore { id: geometryCore }
  readonly property var layout: {
    var input = windows.map(function(record) {
      return record ? { minimized: record.minimized, rect: record.rect, monitorRect: record.monitorRect } : null
    })
    var result = JSON.parse(geometryCore.evaluate("layout", JSON.stringify(input)))
    return result && !result.error ? result : []
  }
  readonly property real monitorAspect: {
    for (var i = 0; i < windows.length; i++) {
      var rect = windows[i] && windows[i].monitorRect
      if (rect && rect.width > 0 && rect.height > 0) return rect.width / rect.height
    }
    return 16 / 9
  }
  radius: Math.max(0, presentation.cornerRadius - presentation.previewInset)
  color: selected ? Commons.Util.alpha(Commons.Color.accent, 0.09) : "transparent"
  border.width: 1
  border.color: selected ? Commons.Color.accent : "transparent"

  Item {
    id: previewFrame
    anchors { top: parent.top; left: parent.left; right: parent.right; bottom: label.top }
    anchors.margins: card.presentation.previewInset
    clip: true

    Rectangle {
      anchors.fill: parent
      color: Qt.darker(Commons.Color.menu.background, 1.18)
    }
    Item {
      id: workspaceSurface
      clip: true
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height * card.monitorAspect)
      height: Math.min(parent.height, parent.width / card.monitorAspect)

      Rectangle {
        anchors.fill: parent
        color: Qt.darker(Commons.Color.menu.background, 1.32)
        border.width: Commons.Style.spacing.hairline
        border.color: Commons.Util.alpha(Commons.Color.foreground, 0.10)
      }
      Repeater {
        model: card.windows.length
        delegate: Item {
          id: miniWindow
          required property int index
          readonly property var windowData: card.windows[index]
          readonly property var cell: index < card.layout.length ? card.layout[index] : null
          visible: cell !== null && cell.hidden !== true
          x: cell ? cell.x * workspaceSurface.width : 0
          y: cell ? cell.y * workspaceSurface.height : 0
          width: cell ? Math.max(1, cell.width * workspaceSurface.width) : 1
          height: cell ? Math.max(1, cell.height * workspaceSurface.height) : 1
          z: card.windows.length - index

          Rectangle {
            anchors.fill: parent
            color: Qt.darker(Commons.Color.menu.background, 1.08)
            border.width: Commons.Style.spacing.hairline
            border.color: Commons.Util.alpha(Commons.Color.foreground, 0.22)
          }
          ScreencopyView {
            anchors.fill: parent
            anchors.margins: Commons.Style.spacing.hairline
            captureSource: card.captureEnabled && miniWindow.visible
              && card.captureStart + miniWindow.index < card.captureLimit
              && miniWindow.windowData ? miniWindow.windowData.toplevel : null
            live: false
            paintCursor: false
            constraintSize: Qt.size(Math.max(1, width), Math.max(1, height))
            visible: hasContent
            onHasContentChanged: if (hasContent) card.frameReady()
          }
        }
      }
    }
  }
  Text {
    id: label
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    leftPadding: Commons.Style.space(12)
    rightPadding: Commons.Style.space(12)
    height: card.presentation.labelHeight
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: card.groupData ? card.groupData.label : ""
    color: card.selected ? Commons.Color.menu.selectedText : Commons.Color.menu.text
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
    font.weight: card.selected ? Font.DemiBold : Font.Medium
    elide: Text.ElideRight
    maximumLineCount: 1
  }
}
