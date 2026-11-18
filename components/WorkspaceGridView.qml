import QtQuick

// A single scrolling row. Captures are scheduled only for visible cards,
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
  signal cardActivated(int index)
  signal frameReady()

  clip: true
  cellWidth: metrics.cellWidth
  cellHeight: height
  flow: GridView.FlowTopToBottom
  flickableDirection: Flickable.HorizontalFlick
  boundsBehavior: Flickable.StopAtBounds
  interactive: contentWidth > width
  highlightFollowsCurrentItem: false
  cacheBuffer: cellWidth
  model: workspaceGroups

  readonly property var captureOffsets: {
    var offsets = []
    // Reading GridView.model during Qt's model replacement can re-enter its
    // delegate-model getter. Schedule from the plain input array instead.
    var entries = workspaceGroups || []
    var total = entries.length
    var next = 0
    for (var i = 0; i < total; i++) offsets.push(-1)
    // In this one-row grid, cells map directly to horizontal positions.
    if (selectedIndex >= 0 && selectedIndex < total && entries[selectedIndex]) {
      offsets[selectedIndex] = 0
      next = entries[selectedIndex].size
    }
    for (var j = 0; j < total; j++) {
      if (!entries[j] || j === selectedIndex || (j + 1) * cellWidth <= contentX || j * cellWidth >= contentX + width) continue
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
    readonly property bool inViewport: (index + 1) * view.cellWidth > view.contentX
      && index * view.cellWidth < view.contentX + view.width
    WorkspaceCard {
      anchors.centerIn: parent
      width: view.metrics.cardWidth
      height: Math.min(view.metrics.cardHeight, parent.height)
      groupData: workspaceCell.modelData
      windows: view.windows.slice(workspaceCell.modelData.startIndex, workspaceCell.modelData.startIndex + workspaceCell.modelData.size)
      presentation: view.presentation
      selected: workspaceCell.index === view.selectedIndex
      captureEnabled: view.switcherOpen && workspaceCell.inViewport
      captureStart: view.captureOffsets[workspaceCell.index] === undefined ? 0 : view.captureOffsets[workspaceCell.index]
      captureLimit: view.captureLimit
      onActivated: view.cardActivated(workspaceCell.index)
      onFrameReady: view.frameReady()
    }
  }
}
