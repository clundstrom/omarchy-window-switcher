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
  property real openingWidth: 0
  property real openingHeight: 0
  property var openingPositions: []
  property var appCases: [[5120,1440,6],[1920,1080,12],[960,540,20],[960,540,0]]
  property var windowCases: [[5120,1440,5],[3440,1440,6,800],[1920,1080,10,800],[960,540,12,800]]
  property var cases: [[5120,1440,1],[5120,1440,5],[5120,1440,6],[5120,1440,12],[1920,1080,5],[1280,720,12],[960,540,12],[1920,1080,1],[1920,1080,0],[960,540,1,960],[960,540,6,960],[1920,1080,6,400,1],[3440,1440,6,800],[1920,1080,10,800],[960,540,12,800]]
  Plugin.ApplicationMetadata { id: appMetadata }
  Plugin.WorkspacePresentation { id: style }
  Plugin.WorkspaceGridView {
    id: grid
    windows: []
    workspaceGroups: []
    presentation: style
    width: metrics.viewportWidth
    height: metrics.viewportHeight
    metrics: style.layoutMetricsFor(test.width - 48 - style.padding * 2,
      windows, test.height - 48 - style.padding * 2, workspaceGroups.length)
    selectedIndex: 0
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
      if (cell.children[i].item) return cell.children[i].item
    }
    return null
  }
  function checkApplicationMetadata() {
    check(Object.keys(appMetadata.lookup("org.example.App")).length === 0, "disabled app provider does no lookups")
    var generic = appMetadata.iconSource("")
    for (var invalid of ["https:" + "//example.invalid/icon.png", "//example.invalid/icon.png",
        "file:" + "//example.invalid/icon.png", "image:custom-provider", "../relative/icon.png"])
      check(appMetadata.iconSource(invalid) === generic, "icon source accepts only native names and local paths")
    check(appMetadata.iconSource("/tmp/example image#1.png") === "file:///tmp/example%20image%231.png", "local icon paths are encoded")
    check(appMetadata.iconSource("/tmp/%file.png") === "file:///tmp/%25file.png", "local paths preserve percent signs")
    appMetadata.enabled = true
    for (var id of ["__proto__", "constructor", "toString"]) {
      var value = appMetadata.lookup(id)
      check(value.id === id && value.name === id, "unmatched application IDs get safe fallback metadata")
      check(appMetadata.lookup(id) === value, "app metadata is reused from memory")
    }
    check(Object.keys(appMetadata.cache).length === 3, "prototype-like app IDs are distinct cache entries")
    for (var i = 0; i < 150; i++) appMetadata.lookup("org.example.Unknown" + i)
    check(Object.keys(appMetadata.cache).length <= 128, "app metadata cache remains bounded")
    appMetadata.aliases = { "org.example.Window": "org.example.App.desktop" }
    check(Object.keys(appMetadata.cache).length === 0, "changing app aliases invalidates cached matches")
    check(appMetadata.desktopIdFor("org.example.Window") === "org.example.App", "aliases accept desktop entry filenames")
    check(appMetadata.desktopIdFor("constructor") === "constructor", "inherited alias properties are ignored")
    check(appMetadata.lookup("org.example.Window").id === "org.example.Window", "missing alias entries preserve the original identifier")
    for (var invalidAlias of [null, 12, {}, "", "../some-app", "/tmp/app.desktop", "https:" + "//example.invalid/app", "a".repeat(257)]) {
      appMetadata.aliases = { "org.example.Window": invalidAlias }
      check(appMetadata.desktopIdFor("org.example.Window") === "org.example.Window", "invalid aliases preserve the original identifier")
    }
    var entries = DesktopEntries.applications.values
    if (entries.length) {
      var entry = entries[0]
      appMetadata.aliases = { "org.example.Window": String(entry.id) }
      var matched = appMetadata.lookup("org.example.Window")
      check(matched.id === String(entry.id) && matched.name === String(entry.name), "alias resolves the real desktop entry metadata")
      check(matched.icon === appMetadata.iconSource(entry.icon), "alias uses the desktop entry icon")
    }
    appMetadata.aliases = ({})
    appMetadata.enabled = false
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
  function clippedCard(atLeft) {
    for (var i = 0; i < grid.workspaceGroups.length; i++) {
      var card = cardAt(i)
      if (!card) continue
      var x = card.mapToItem(grid, 0, 0).x
      if (atLeft && x < -1 && x + card.width > 4) return true
      if (!atLeft && x < grid.width - 4 && x + card.width > grid.width + 1) return true
    }
    return false
  }
  function checkSelection() {
    var card = cardAt(grid.selectedIndex)
    check(grid.count === 0 || card !== null, "selected preview exists")
    if (card) {
      var x = card.mapToItem(grid, 0, 0).x
      check(x >= -1 && x + card.width <= grid.width + 1,
        "selected preview stays complete: index=" + grid.selectedIndex + " x=" + x + " width=" + card.width
          + " viewport=" + grid.width + " contentX=" + grid.contentX + " originX=" + grid.originX)
      var y = card.mapToItem(grid, 0, 0).y
      check(y >= -1 && y + card.height <= grid.height + 1, "selected preview fits vertically")
    }
    check(Math.abs(grid.width - openingWidth) < 1, "navigation keeps row width fixed")
    check(Math.abs(grid.height - openingHeight) < 1, "navigation keeps layout height fixed")
    check(grid.width + style.padding * 2 <= test.width - 48 + 1, "row fits the screen width")
    if (grid.wrapped) {
      check(!grid.interactive && grid.contentX === grid.originX && grid.contentY === grid.originY, "wrapped layout never scrolls")
      var positions = []
      for (var j = 0; j < grid.count; j++) {
        var tile = cardAt(j)
        check(tile !== null, "all wrapped previews exist")
        if (!tile) continue
        var point = tile.mapToItem(grid, 0, 0)
        check(point.x >= -1 && point.x + tile.width <= grid.width + 1
          && point.y >= -1 && point.y + tile.height <= grid.height + 1, "every wrapped preview is fully visible")
        positions.push({ x: point.x, y: point.y })
        if (openingPositions.length > j)
          check(Math.abs(point.x - openingPositions[j].x) < 1 && Math.abs(point.y - openingPositions[j].y) < 1,
            "wrapped previews stay stationary as selection changes")
      }
      if (!openingPositions.length) openingPositions = positions
      return
    }
    if (!style.applicationMode && test.width === 5120 && grid.count >= 5) {
      var complete = 0
      for (var i = 0; i < grid.count; i++) {
        var preview = cardAt(i)
        if (!preview) continue
        var left = preview.mapToItem(grid, 0, 0).x
        if (left >= -1 && left + preview.width <= grid.width + 1) complete++
      }
      check(complete === 5, "wide screen retains five complete previews")
    }
    var overflowing = grid.workspaceGroups.length * grid.cellWidth > grid.width + 1
    if (overflowing) {
      if (grid.contentX > grid.originX + 1) check(clippedCard(true), "hidden workspaces have a leading preview slice")
      if (grid.contentX + grid.width < grid.originX + grid.workspaceGroups.length * grid.cellWidth - 1)
        check(clippedCard(false), "hidden workspaces have a trailing preview slice")
    } else {
      check(!clippedCard(true) && !clippedCard(false), "fitting rows have no clipped previews")
    }
  }
  Timer {
    interval: 100
    running: true
    repeat: true
    onTriggered: {
      var phase = test.stage % 4
      if (phase === 0) {
        if (test.stage / 4 >= (test.cases.length + test.windowCases.length + test.appCases.length) * 2) {
          test.checkBounds()
          test.checkApplicationMetadata()
          console.log("RESULT failures=" + test.failures)
          Qt.quit()
          return
        }
        var caseIndex = test.stage / 4
        var appMode = caseIndex >= (test.cases.length + test.windowCases.length) * 2
        var windowMode = !appMode && caseIndex >= test.cases.length * 2
        var pool = appMode ? test.appCases : (windowMode ? test.windowCases : test.cases)
        var localIndex = appMode ? caseIndex - (test.cases.length + test.windowCases.length) * 2
          : (windowMode ? caseIndex - test.cases.length * 2 : caseIndex)
        var c = pool[localIndex % pool.length]
        test.width = c[0]; test.height = c[1]
        style.settings = { thumbnailWidth: c.length > 3 ? c[3] : 400, maxVisible: c.length > 4 ? c[4] : 5,
          overflowMode: localIndex >= pool.length ? "wrap" : "scroll",
          switchMode: appMode ? "applications" : (windowMode ? "windows" : "workspaces") }
        var windows = []; var groups = []
        for (var i = 0; i < c[2]; i++) {
          windows.push({monitorRect: {x:0,y:0,width:c[0],height:c[1]}, rect:{x:0,y:0,width:c[0],height:c[1]}, workspaceId:i+1, toplevel:null, minimized:false})
          groups.push({id:i+1,key:String(i+1),label:"Workspace "+(i+1),startIndex:i,size:1})
        }
        grid.windows = windows; grid.workspaceGroups = groups
        grid.selectedIndex = c[2] ? 0 : -1
        test.openingWidth = grid.width
        test.openingHeight = grid.height
        test.openingPositions = []
        Qt.callLater(function() {
          grid.revealSelection()
        })
      } else if (phase === 1 || phase === 2) {
        test.checkSelection()
        grid.selectedIndex = phase === 1 ? Math.floor(grid.count / 2) : grid.count - 1
      } else {
        test.checkSelection()
        test.check(grid.flow === (grid.wrapped ? GridView.FlowLeftToRight : GridView.FlowTopToBottom), "layout flow matches overflow setting")
        test.check(grid.contentHeight <= grid.height + 1, "rows fit without vertical scrolling")
        var selected = grid.itemAtIndex(grid.selectedIndex)
        test.check(grid.count === 0 || selected !== null, "selected workspace exists")
        if (selected) {
          var x = selected.mapToItem(grid.contentItem, 0, 0).x
          test.check(x >= grid.contentX - 1, "selected workspace left edge is visible")
          test.check(x + selected.width <= grid.contentX + grid.width + 1, "selected workspace right edge is visible")
        }
        if (style.applicationMode) test.check(grid.captureOffsets.length === 0, "application icons schedule no captures")
        else if (grid.count > 0) test.check(grid.captureOffsets[grid.selectedIndex] === 0, "selected workspace captures first")
        else test.check(grid.captureOffsets.length === 0, "empty workspace lists schedule no captures")
        for (var j = 0; j < grid.count; j++) {
          var card = test.cardAt(j)
          var inViewport = grid.inViewport(j)
          if (card) test.check((style.applicationMode ? card.interactive : card.captureEnabled) === inViewport, "offscreen cards detach capture sources")
          if (!style.applicationMode && !inViewport && j !== grid.selectedIndex)
            test.check(grid.captureOffsets[j] === -1, "offscreen cards consume no capture budget")
        }
        grid.switcherOpen = false
        for (var k = 0; k < grid.count; k++) {
          var closedCard = test.cardAt(k)
          if (closedCard) test.check(!(style.applicationMode ? closedCard.interactive : closedCard.captureEnabled), "closing detaches all capture sources")
        }
        grid.switcherOpen = true
        test.check(grid.height + style.padding * 2 < test.height, "strip fits vertically")
        test.check(grid.metrics.cardWidth <= (style.applicationMode ? style.appIconSize + Commons.Style.space(32) : style.thumbnailWidth), "cards respect preferred width")
        console.log("CHECK geometry " + test.width + "x" + test.height + " count=" + grid.count
          + " mode=" + style.settings.overflowMode + "/" + style.settings.switchMode + " strip=" + grid.width + "x" + grid.height)
      }
      test.stage++
    }
  }
}
