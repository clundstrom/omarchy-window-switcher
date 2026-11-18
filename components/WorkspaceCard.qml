import QtQuick
import Quickshell.Wayland
import qs.Commons as Commons
import "../native" as Native

// Native window composition with a flat frame and a quiet numeric label.
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
  color: "transparent"

  Item {
    id: previewFrame
    anchors { top: parent.top; left: parent.left; right: parent.right; bottom: labelRow.top }
    clip: true

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.background
    }
    Item {
      id: workspaceSurface
      clip: true
      anchors.centerIn: parent
      width: Math.min(parent.width - card.presentation.previewInset * 2,
        (parent.height - card.presentation.previewInset * 2) * card.monitorAspect)
      height: width / card.monitorAspect

      Image {
        anchors.fill: parent
        source: card.presentation.sessionWallpaper
        sourceSize.width: card.presentation.thumbnailWidth * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        retainWhileLoading: true
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
    Rectangle {
      anchors.fill: parent
      color: "transparent"
      radius: card.presentation.cornerRadius
      border.width: card.selected ? 2 : 1
      border.color: card.selected ? Commons.Color.imagePicker.selectedBorder : Commons.Color.imagePicker.unselectedBorder
    }
  }
  Item {
    id: labelRow
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: card.presentation.labelHeight
    Row {
      anchors.centerIn: parent
      spacing: Commons.Style.space(6)
      Rectangle {
        width: Commons.Style.space(5)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.accent
        border.width: Commons.Style.spacing.hairline
        border.color: Commons.Util.alpha(Commons.Color.background, 0.7)
        opacity: card.selected ? 1 : 0
      }
      Text {
        textFormat: Text.PlainText
        text: card.groupData ? String(card.groupData.id) : ""
        color: Commons.Color.imagePicker.text
        style: Text.Outline
        styleColor: Commons.Util.alpha(Commons.Color.background, 0.7)
        opacity: card.selected ? 1 : 0.85
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
        font.weight: card.selected ? Font.DemiBold : Font.Normal
      }
    }
  }
}
