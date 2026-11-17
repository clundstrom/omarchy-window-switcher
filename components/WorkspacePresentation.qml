import QtQuick
import Quickshell.Io
import qs.Commons

// Presentation settings are local to the plugin: no dependency on the host's
// private shellConfig API, and no change to switching or invocation options.
QtObject {
  id: presentation

  property var settings: ({})
  readonly property bool enabled: settings.enabled !== false
  readonly property int thumbnailWidth: Style.space(number("thumbnailWidth", 264, 160, 400))
  readonly property int maxVisible: number("maxVisible", 5, 1, 8)
  readonly property int spacing: Style.space(number("spacing", 12, 4, 32))
  readonly property int padding: Style.space(number("padding", 16, 8, 40))
  readonly property int cornerRadius: Style.space(number("cornerRadius", 16, 0, 32))
  readonly property int labelHeight: Style.space(32)
  readonly property int previewInset: Style.space(4)
  readonly property real backgroundOpacity: number("backgroundOpacity", 0.96, 0.5, 1)
  readonly property bool showHeader: settings.showHeader === true
  readonly property bool showFooter: settings.showFooter === true
  readonly property bool showDetails: settings.showDetails === true
  readonly property bool showCloseButtons: settings.showCloseButtons === true

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
