import QtQuick
import Quickshell.Io
import qs.Commons as Commons

// Presentation settings are local to the plugin: no dependency on the host's
// private shellConfig API, and no change to switching or invocation options.
QtObject {
  id: presentation

  property var settings: ({})
  readonly property int thumbnailWidth: Commons.Style.space(number("thumbnailWidth", 264, 160, 400))
  readonly property int maxVisible: number("maxVisible", 5, 1, 8)
  readonly property int spacing: Commons.Style.space(number("spacing", 12, 4, 32))
  readonly property int padding: Commons.Style.space(number("padding", 16, 8, 40))
  readonly property int cornerRadius: Commons.Style.space(number("cornerRadius", 16, 0, 32))
  readonly property int labelHeight: Commons.Style.space(32)
  readonly property int previewInset: Commons.Style.space(4)
  readonly property real backgroundOpacity: number("backgroundOpacity", 0.96, 0.5, 1)

  function metricsFor(availableWidth, windows) {
    var aspect = 0
    for (var i = 0; i < windows.length; i++) {
      var rect = windows[i] && windows[i].monitorRect
      if (rect && rect.width > 0 && rect.height > 0) {
        var candidate = rect.width / rect.height
        aspect = aspect > 0 ? Math.min(aspect, candidate) : candidate
      }
    }
    if (!(aspect > 0)) aspect = 16 / 9
    var cardWidth = Math.max(previewInset * 2 + 1, Math.min(thumbnailWidth, availableWidth - spacing))
    var cardHeight = (cardWidth - previewInset * 2) / aspect + labelHeight + previewInset * 2
    return { cardWidth: cardWidth, cardHeight: cardHeight, cellWidth: cardWidth + spacing, cellHeight: cardHeight }
  }

  function number(key, fallback, low, high) {
    var value = settings[key]
    return typeof value === "number" && isFinite(value)
      ? Math.max(low, Math.min(high, value)) : fallback
  }

  property FileView configFile: FileView {
    path: Qt.resolvedUrl("../compact.json")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        let value = JSON.parse(text())
        presentation.settings = value && typeof value === "object" && !Array.isArray(value) ? value : ({})
      } catch (error) {
        console.warn("Window switcher: invalid compact.json, using presentation defaults")
        presentation.settings = ({})
      }
    }
    onLoadFailed: presentation.settings = ({})
  }
}
