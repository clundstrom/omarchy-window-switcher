import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

QtObject {
  id: presentation

  property var settings: ({})
  readonly property int thumbnailWidth: Commons.Style.space(number("thumbnailWidth", 800, 160, 960))
  readonly property int maxVisible: number("maxVisible", 5, 1, 8)
  readonly property bool wrapOverflow: settings.overflowMode === "wrap"
  readonly property int spacing: Commons.Style.space(number("spacing", 28, 4, 64))
  readonly property int padding: Commons.Style.space(number("padding", 24, 8, 48))
  readonly property int cornerRadius: Commons.Style.space(number("cornerRadius", 0, 0, 32))
  readonly property int labelHeight: Commons.Style.space(36)
  readonly property int previewInset: Commons.Style.space(2)
  readonly property real backgroundOpacity: number("backgroundOpacity", 0.38, 0, 1)
  readonly property bool showWallpaper: typeof settings.showWallpaper === "boolean" ? settings.showWallpaper : true
  property string backgroundPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property int wallpaperVersion: 0
  readonly property url wallpaperSource: showWallpaper
    ? Commons.Util.fileUrl(backgroundPath) + "?switcher=" + wallpaperVersion : ""
  property url sessionWallpaper: ""

  function prepareOpen() {
    // Freeze an already decoded image for this opening. A slow wallpaper must
    // not delay the switcher or appear halfway through an interaction.
    sessionWallpaper = wallpaperPreload.status === Image.Ready ? wallpaperSource : ""
  }
  function number(key, fallback, low, high) {
    var value = settings[key]
    return typeof value === "number" && isFinite(value)
      ? Math.max(low, Math.min(high, value)) : fallback
  }
  function metricsFor(availableWidth, windows, availableHeight) {
    var aspect = 0
    for (var i = 0; i < windows.length; i++) {
      var rect = windows[i] && windows[i].monitorRect
      if (rect && rect.width > 0 && rect.height > 0) {
        var candidate = rect.width / rect.height
        aspect = aspect > 0 ? Math.min(aspect, candidate) : candidate
      }
    }
    if (!(aspect > 0)) aspect = 16 / 9
    var heightLimit = typeof availableHeight === "number" && availableHeight > 0 ? availableHeight : Infinity
    var widthFromHeight = Math.max(1, heightLimit - labelHeight - previewInset * 2) * aspect + previewInset * 2
    var cardWidth = Math.max(previewInset * 2 + 1,
      Math.min(thumbnailWidth, availableWidth - spacing, widthFromHeight))
    var cardHeight = (cardWidth - previewInset * 2) / aspect + labelHeight + previewInset * 2
    return { cardWidth: cardWidth, cardHeight: cardHeight, cellWidth: cardWidth + spacing, cellHeight: cardHeight }
  }

  function rowMetricsFor(availableWidth, windows, availableHeight, workspaceCount) {
    var metrics = metricsFor(availableWidth, windows, availableHeight)
    var visible = Math.max(1, Math.min(maxVisible, workspaceCount))
    var fits = workspaceCount <= maxVisible && workspaceCount * metrics.cellWidth <= availableWidth
    if (fits) {
      metrics.viewportWidth = visible * metrics.cellWidth
      return metrics
    }
    // Keep a fifth of the neighbouring preview visible past the complete cards.
    // Include its half-gap so the cue shows image content, not just spacing.
    var peek = spacing / 2 + metrics.cardWidth * 0.2
    if (metrics.cellWidth + peek > availableWidth) {
      var cardLimit = Math.max(1, (availableWidth - spacing * 1.5) / 1.2)
      metrics = metricsFor(cardLimit + spacing, windows, availableHeight)
      peek = spacing / 2 + metrics.cardWidth * 0.2
    }
    visible = Math.max(1, Math.min(visible, Math.floor((availableWidth - peek) / metrics.cellWidth)))
    metrics.viewportWidth = Math.min(availableWidth, visible * metrics.cellWidth + peek)
    return metrics
  }

  function layoutMetricsFor(availableWidth, windows, availableHeight, workspaceCount) {
    if (!wrapOverflow) {
      var row = rowMetricsFor(availableWidth, windows, availableHeight, workspaceCount)
      row.viewportHeight = row.cardHeight
      return row
    }
    var preferred = metricsFor(availableWidth, windows, availableHeight)
    var limit = Math.max(1, Math.min(maxVisible, workspaceCount))
    var columns = Math.max(1, Math.min(limit, Math.floor(availableWidth / preferred.cellWidth)))
    var rows = Math.max(1, Math.ceil(workspaceCount / columns))
    var gap = rows > 1 ? spacing : 0
    var best = null
    // Preserve the preferred size when it fits. Add columns and reduce size
    // only when the wrapped rows would exceed the monitor's logical height.
    for (var count = columns; count <= limit; count++) {
      rows = Math.max(1, Math.ceil(workspaceCount / count))
      gap = rows > 1 ? spacing : 0
      var candidate = metricsFor(availableWidth / count, windows, availableHeight / rows - gap)
      candidate.columns = count
      candidate.cellHeight = candidate.cardHeight + gap
      candidate.viewportWidth = count * candidate.cellWidth
      candidate.viewportHeight = rows * candidate.cellHeight
      if (!best || candidate.cardWidth > best.cardWidth) best = candidate
      if (count === columns && candidate.cardWidth >= preferred.cardWidth - 0.5) break
    }
    return best
  }

  // This is the existing wallpaper file, decoded once in memory. FileView
  // watches it without loading its binary contents or creating another file.
  property Image wallpaperPreload: Image {
    source: presentation.wallpaperSource
    sourceSize.width: presentation.thumbnailWidth * 2
    asynchronous: true
    cache: true
    visible: false
  }
  property FileView wallpaperWatcher: FileView {
    path: presentation.backgroundPath
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: presentation.wallpaperVersion++
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
        console.warn("Workspace switcher: invalid compact.json, using presentation defaults")
        presentation.settings = ({})
      }
    }
    onLoadFailed: presentation.settings = ({})
  }
}
