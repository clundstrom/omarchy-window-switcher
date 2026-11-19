pragma ComponentBehavior: Bound
import QtQuick

// A scrolling row or stationary wrapped rows. Capture visible cards,
// selected workspace first, within one shared bounded capture budget.
GridView {
  id: view
  required property var windows
  required property var workspaceGroups
  required property var metrics
  required property var presentation
  required property int selectedIndex
  required property bool switcherOpen
  required property int captureLimit
  signal frameReady()
  signal workspaceActivated(string workspaceKey)
  readonly property bool wrapped: presentation.wrapOverflow

  clip: true
  cellWidth: metrics.cellWidth
  cellHeight: metrics.cellHeight
  flow: wrapped ? GridView.FlowLeftToRight : GridView.FlowTopToBottom
  flickableDirection: Flickable.HorizontalFlick
  boundsBehavior: Flickable.StopAtBounds
  interactive: !wrapped && contentWidth > width
  highlightFollowsCurrentItem: false
  cacheBuffer: cellWidth
  model: workspaceGroups

  function revealSelection() {
    if (!switcherOpen || selectedIndex < 0 || width <= 0 || cellWidth <= 0) return
    forceLayout()
    var entries = workspaceGroups || []
    if (selectedIndex >= entries.length) return
    contentY = originY
    if (wrapped) { contentX = originX; return }
    // Keep complete cards between the clipped neighbours, with selection near
    // the centre. Clamp at either end to keep the first/last card complete.
    var complete = Math.max(1, Math.floor(width / cellWidth))
    var first = selectedIndex - Math.floor(complete / 2)
    var next = first * cellWidth - (width - complete * cellWidth) / 2
    contentX = originX + Math.max(0, Math.min(next, Math.max(0, entries.length * cellWidth - width)))
  }
  onSelectedIndexChanged: Qt.callLater(view.revealSelection)
  onWorkspaceGroupsChanged: Qt.callLater(view.revealSelection)
  onWidthChanged: Qt.callLater(view.revealSelection)
  onCellWidthChanged: Qt.callLater(view.revealSelection)
  onCellHeightChanged: Qt.callLater(view.revealSelection)
  onWrappedChanged: Qt.callLater(view.revealSelection)
  onOriginXChanged: Qt.callLater(view.revealSelection)
  onOriginYChanged: Qt.callLater(view.revealSelection)
  onSwitcherOpenChanged: if (switcherOpen) Qt.callLater(view.revealSelection)

  function inViewport(index) {
    var columns = wrapped ? Math.max(1, metrics.columns) : 1
    var x = originX + (wrapped ? index % columns : index) * cellWidth
    var y = originY + (wrapped ? Math.floor(index / columns) * cellHeight : 0)
    return x + cellWidth > contentX && x < contentX + width
      && y + cellHeight > contentY && y < contentY + height
  }

  readonly property var captureOffsets: {
    var offsets = []
    if (presentation.applicationMode) return offsets
    // Reading GridView.model during Qt's model replacement can re-enter its
    // delegate-model getter. Schedule from the plain input array instead.
    var entries = workspaceGroups || []
    var total = entries.length
    var next = 0
    for (var i = 0; i < total; i++) offsets.push(-1)
    if (selectedIndex >= 0 && selectedIndex < total && entries[selectedIndex]) {
      offsets[selectedIndex] = 0
      next = entries[selectedIndex].size
    }
    for (var j = 0; j < total; j++) {
      if (!entries[j] || j === selectedIndex || !view.inViewport(j)) continue
      offsets[j] = next
      next += entries[j].size
    }
    return offsets
  }

  delegate: Item {
    id: workspaceCell
    required property int index
    required property var modelData
    width: view.cellWidth
    height: view.cellHeight
    readonly property bool inViewport: view.inViewport(index)
    Loader {
      id: cardLoader
      anchors.centerIn: parent
      width: view.metrics.cardWidth
      height: Math.min(view.metrics.cardHeight, parent.height)
      sourceComponent: view.presentation.applicationMode ? applicationCard : previewCard
      readonly property var entryWindows: view.windows.slice(workspaceCell.modelData.startIndex,
        workspaceCell.modelData.startIndex + workspaceCell.modelData.size)
      Component {
        id: applicationCard
        ApplicationCard {
          groupData: workspaceCell.modelData
          windows: cardLoader.entryWindows
          presentation: view.presentation
          selected: workspaceCell.index === view.selectedIndex
          interactive: view.switcherOpen && workspaceCell.inViewport
          onFrameReady: view.frameReady()
          onActivated: function(workspaceKey) { view.workspaceActivated(workspaceKey) }
        }
      }
      Component {
        id: previewCard
        WorkspaceCard {
          groupData: workspaceCell.modelData
          windows: cardLoader.entryWindows
          presentation: view.presentation
          selected: workspaceCell.index === view.selectedIndex
          captureEnabled: view.switcherOpen && workspaceCell.inViewport
          captureStart: view.captureOffsets[workspaceCell.index] === undefined ? 0 : view.captureOffsets[workspaceCell.index]
          captureLimit: view.captureLimit
          onFrameReady: view.frameReady()
          onActivated: function(workspaceKey) { view.workspaceActivated(workspaceKey) }
        }
      }
    }
  }
}
