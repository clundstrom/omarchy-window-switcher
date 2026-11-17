import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "plugin/components" as Plugin

Window {
  id: test
  width: 1920
  height: 1080
  visible: true
  property int stage: 0
  property int failures: 0
  property var cases: [[5120,1440,1],[5120,1440,12],[1920,1080,5],[1280,720,12],[960,540,12],[1920,1080,1]]
  Plugin.WorkspacePresentation { id: style }
  Plugin.SwitcherViewArea {
    id: area
    windows: []
    groups: []
    compact: true
    presentation: style
    width: Math.min(test.width - 48, Math.max(1, Math.min(style.maxVisible, groups.length)) * (style.thumbnailWidth + style.spacing))
    height: compactCardHeight
    viewMode: "workspaces"
    selectedIndex: groups.length - 1
    focusedWorkspaceId: 1
    switcherOpen: true
    previewMode: "none"
    captureLimit: 0
    workspaceNames: ({})
    animationMs: 0
    query: ""
    activeFilter: ({kind: "all"})
    allWindowsCount: windows.length
    hiddenMinimizedCount: 0
    renamingWorkspaceId: 0
  }
  function check(value, description) {
    if (!value) { failures++; console.error("FAIL: " + description) }
  }
  function grid() {
    for (var i = 0; i < area.children.length; i++) {
      var child = area.children[i]
      if (child.item && child.item.positionViewAtIndex) return child.item
    }
    return null
  }
  Timer {
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      if (test.stage % 2 === 0) {
        if (test.stage / 2 >= test.cases.length) {
          console.log("RESULT failures=" + test.failures)
          Qt.quit()
          return
        }
        var c = test.cases[test.stage / 2]
        test.width = c[0]; test.height = c[1]
        var windows = []; var groups = []
        for (var i = 0; i < c[2]; i++) {
          windows.push({monitorRect: {x:0,y:0,width:c[0],height:c[1]}, workspaceId:i+1, title:"Test", iconSource:"", minimized:false})
          groups.push({id:i+1,key:String(i+1),defaultLabel:"Workspace "+(i+1),startIndex:i,size:1,totalSize:1})
        }
        area.windows = windows; area.groups = groups
        Qt.callLater(function() { area.reveal(area.selectedIndex) })
      } else {
        var g = test.grid()
        test.check(g !== null, "workspace grid loaded")
        if (g) {
          test.check(g.flow === GridView.FlowTopToBottom, "horizontal flow")
          test.check(g.contentHeight <= g.height + 1, "single row")
          test.check(g.itemAtIndex(area.selectedIndex) !== null, "selected card exists")
          if (g.itemAtIndex(area.selectedIndex)) {
            test.check(g.itemAtIndex(area.selectedIndex).mapToItem(g.contentItem, 0, 0).x >= g.contentX - 1, "selected card left contained")
            test.check(g.itemAtIndex(area.selectedIndex).mapToItem(g.contentItem, 0, 0).x + g.itemAtIndex(area.selectedIndex).width <= g.contentX + g.width + 1, "selected card right contained")
          }
        }
        test.check(area.height + style.padding * 2 < test.height, "panel fits vertically")
        console.log("CHECK geometry " + test.width + "x" + test.height + " count=" + area.groups.length + " strip=" + area.width + "x" + area.height)
      }
      test.stage++
    }
  }
}
