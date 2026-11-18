import QtQuick
import QtTest 1.3
import "../native" as Native

TestCase {
  name: "RustWorkspaceCore"
  Native.WorkspaceCore { id: core }
  function call(operation, input) { return JSON.parse(core.evaluate(operation, JSON.stringify(input))) }
  function test_navigation() {
    compare(core.step(0, -1, 3), 2)
    compare(core.step(2, 1, 3), 0)
    compare(core.step(0, 1, 0), -1)
  }
  function test_workspace_history() {
    compare(call("workspaceFocus", { keys: ["1", "3", "1"], workspaceId: 3 }), ["3", "1"])
  }
  function test_window_and_workspace_focus() {
    compare(call("focus", { mruKeys: ["a", "b", "gone"], workspaceHistory: ["1", "2"],
      liveKeys: ["a", "b"], key: "b", workspaceId: 2 }),
      { mruKeys: ["b", "a"], workspaceHistory: ["2", "1"] })
  }
  function test_scrolling_geometry() {
    var cells = call("layout", [{ rect: { x: -500, y: -100, width: 5000, height: 2000 },
      monitorRect: { x: 0, y: 0, width: 3440, height: 1440 }, minimized: false }])
    compare(cells.length, 1)
    compare(cells[0].hidden, false)
    compare(cells[0].x, -500 / 3440)
    compare(cells[0].width, 5000 / 3440)
  }
  function test_rejects_invalid_input() {
    verify(call("unknown", {}).error !== undefined)
    verify(JSON.parse(core.evaluate("layout", "{")).error !== undefined)
  }
}
