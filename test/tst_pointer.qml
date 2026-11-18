import QtQuick
import QtTest 1.3
import "../components" as Plugin

TestCase {
  name: "WorkspacePointer"
  when: windowShown
  width: 200
  height: 100
  visible: true
  Plugin.WorkspaceTapTarget { id: target; anchors.fill: parent }
  SignalSpy { id: activation; target: target; signalName: "activated" }
  function init() { target.enabled = true; activation.clear() }
  function test_left_click_activates_on_release() {
    mousePress(target, 100, 50, Qt.LeftButton)
    compare(activation.count, 0)
    mouseRelease(target, 100, 50, Qt.LeftButton)
    tryCompare(activation, "count", 1)
  }
  function test_right_click_is_ignored() {
    mouseClick(target, 100, 50, Qt.RightButton)
    compare(activation.count, 0)
  }
  function test_hover_is_ignored() {
    mouseMove(target, 50, 30)
    mouseMove(target, 100, 50)
    compare(activation.count, 0)
  }
  function test_drag_cancels_activation() {
    mousePress(target, 20, 50, Qt.LeftButton)
    mouseMove(target, 160, 50)
    mouseRelease(target, 160, 50, Qt.LeftButton)
    compare(activation.count, 0)
  }
  function test_disabled_target_is_ignored() {
    target.enabled = false
    mouseClick(target, 100, 50, Qt.LeftButton)
    compare(activation.count, 0)
  }
}
