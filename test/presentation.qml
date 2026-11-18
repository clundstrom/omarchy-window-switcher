import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons as Commons
import "plugin/components" as Plugin

Window {
  id: test
  width: 1920
  height: 1080
  visible: true
  property int stage: 0
  property int failures: 0
  property var cases: [[5120,1440,1],[5120,1440,12],[1920,1080,5],[1280,720,12],[960,540,12],[1920,1080,1],[1920,1080,0],[960,540,1,960]]
  Plugin.WorkspacePresentation { id: style }
  Plugin.WorkspaceGridView {
    id: grid
    windows: []
    workspaceGroups: []
    presentation: style
    width: Math.min(test.width - 48, Math.max(1, Math.min(style.maxVisible, count)) * (style.thumbnailWidth + style.spacing))
    height: metrics.cardHeight
    metrics: style.metricsFor(width, windows, test.height - 48 - style.padding * 2)
    selectedIndex: count - 1
    switcherOpen: true
    captureLimit: 0
  }
  function check(value, description) {
    if (!value) { failures++; console.error("FAIL: " + description) }
  }
  function cardAt(index) {
    var cell = grid.itemAtIndex(index)
    if (!cell) return null
    for (var i = 0; i < cell.children.length; i++) {
      if (cell.children[i].captureEnabled !== undefined) return cell.children[i]
    }
    return null
  }
  function checkBounds() {
    var original = style.settings
    style.settings = { thumbnailWidth: 0, maxVisible: 99, spacing: -1, padding: 99, cornerRadius: 99, backgroundOpacity: 0 }
    check(style.thumbnailWidth === Commons.Style.space(160), "card width lower bound")
    check(style.maxVisible === 8, "visible card upper bound")
    check(style.spacing === Commons.Style.space(4), "spacing lower bound")
    check(style.padding === Commons.Style.space(48), "padding upper bound")
    check(style.cornerRadius === Commons.Style.space(32), "radius upper bound")
    check(style.backgroundOpacity === 0, "opacity lower bound")
    style.settings = original
  }
  Timer {
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      if (test.stage % 2 === 0) {
        if (test.stage / 2 >= test.cases.length) {
          test.checkBounds()
          console.log("RESULT failures=" + test.failures)
          Qt.quit()
          return
        }
        var c = test.cases[test.stage / 2]
        test.width = c[0]; test.height = c[1]
        if (c.length > 3) style.settings = { thumbnailWidth: c[3] }
        var windows = []; var groups = []
        for (var i = 0; i < c[2]; i++) {
          windows.push({monitorRect: {x:0,y:0,width:c[0],height:c[1]}, rect:{x:0,y:0,width:c[0],height:c[1]}, workspaceId:i+1, toplevel:null, minimized:false})
          groups.push({id:i+1,key:String(i+1),label:"Workspace "+(i+1),startIndex:i,size:1})
        }
        grid.windows = windows; grid.workspaceGroups = groups
        Qt.callLater(function() {
          grid.revealSelection()
        })
      } else {
        test.check(grid.flow === GridView.FlowTopToBottom, "horizontal flow")
        test.check(grid.contentHeight <= grid.height + 1, "single row")
        var selected = grid.itemAtIndex(grid.selectedIndex)
        test.check(grid.count === 0 || selected !== null, "selected workspace exists")
        if (selected) {
          var x = selected.mapToItem(grid.contentItem, 0, 0).x
          test.check(x >= grid.contentX - 1, "selected workspace left edge is visible")
          test.check(x + selected.width <= grid.contentX + grid.width + 1, "selected workspace right edge is visible")
        }
        if (grid.count > 0) test.check(grid.captureOffsets[grid.selectedIndex] === 0, "selected workspace captures first")
        else test.check(grid.captureOffsets.length === 0, "empty workspace lists schedule no captures")
        for (var j = 0; j < grid.count; j++) {
          var card = test.cardAt(j)
          var inViewport = (j + 1) * grid.cellWidth > grid.contentX && j * grid.cellWidth < grid.contentX + grid.width
          if (card) test.check(card.captureEnabled === inViewport, "offscreen cards detach capture sources")
          if (!inViewport && j !== grid.selectedIndex)
            test.check(grid.captureOffsets[j] === -1, "offscreen cards consume no capture budget")
        }
        grid.switcherOpen = false
        for (var k = 0; k < grid.count; k++) {
          var closedCard = test.cardAt(k)
          if (closedCard) test.check(!closedCard.captureEnabled, "closing detaches all capture sources")
        }
        grid.switcherOpen = true
        test.check(grid.height + style.padding * 2 < test.height, "strip fits vertically")
        test.check(grid.metrics.cardWidth <= style.thumbnailWidth, "cards respect preferred width")
        console.log("CHECK geometry " + test.width + "x" + test.height + " count=" + grid.count + " strip=" + grid.width + "x" + grid.height)
      }
      test.stage++
    }
  }
}
