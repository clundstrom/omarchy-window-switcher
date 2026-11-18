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
  signal activated(string workspaceKey)

  Native.WorkspaceCore { id: geometryCore }
  readonly property var layout: {
    if (presentation.windowMode) return [{ x: 0, y: 0, width: 1, height: 1, hidden: false }]
    var input = windows.map(function(record) {
      return record ? { minimized: record.minimized, rect: record.rect, monitorRect: record.monitorRect } : null
    })
    var result = JSON.parse(geometryCore.evaluate("layout", JSON.stringify(input)))
    return result && !result.error ? result : []
  }
  readonly property real monitorAspect: {
    if (presentation.windowMode) {
      var windowRect = windows.length && windows[0] ? windows[0].rect : null
      return windowRect && windowRect.width > 0 && windowRect.height > 0 ? windowRect.width / windowRect.height : 16 / 9
    }
    for (var i = 0; i < windows.length; i++) {
      var rect = windows[i] && windows[i].monitorRect
      if (rect && rect.width > 0 && rect.height > 0) return rect.width / rect.height
    }
    return 16 / 9
  }
  readonly property string windowLabel: {
    if (!presentation.windowMode) return ""
    var source = windows.length && windows[0] ? windows[0].toplevel : null
    var label = source ? String(source.title || source.appId || "") : (groupData ? groupData.label : "")
    label = String(label || "").replace(/\s+/g, " ").slice(0, 512)
    var last = label.charCodeAt(label.length - 1)
    if (last >= 0xd800 && last <= 0xdbff) label = label.slice(0, -1)
    return label || (groupData ? String(groupData.id) : "")
  }
  color: "transparent"

  WorkspaceTapTarget {
    anchors.fill: parent
    z: 1
    enabled: card.captureEnabled
    onActivated: if (card.groupData) card.activated(String(card.groupData.key))
  }

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
        visible: !card.presentation.windowMode
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
            anchors.centerIn: parent
            width: card.presentation.windowMode && sourceSize.height > 0
              ? Math.max(1, Math.min(parent.width - Commons.Style.spacing.hairline * 2,
                  (parent.height - Commons.Style.spacing.hairline * 2) * sourceSize.width / sourceSize.height))
              : Math.max(1, parent.width - Commons.Style.spacing.hairline * 2)
            height: card.presentation.windowMode && sourceSize.width > 0
              ? width * sourceSize.height / sourceSize.width
              : Math.max(1, parent.height - Commons.Style.spacing.hairline * 2)
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
        text: card.presentation.windowMode ? card.windowLabel : (card.groupData ? String(card.groupData.id) : "")
        width: card.presentation.windowMode ? Math.min(implicitWidth, Math.max(0, card.width - Commons.Style.space(32))) : implicitWidth
        elide: Text.ElideRight
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
