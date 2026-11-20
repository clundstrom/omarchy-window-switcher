import QtQuick
import QtTest 1.3
import "../components" as Plugin

TestCase {
  name: "ApplicationOverviewInput"
  when: windowShown
  width: 200
  height: 100
  Plugin.OverviewKeySurface {
    id: surface
    anchors.fill: parent
    onSelectionRequested: function(index) { selectedIndex = index }
  }
  SignalSpy { id: commitSpy; target: surface; signalName: "committed" }
  SignalSpy { id: cancelSpy; target: surface; signalName: "cancelled" }
  function init() {
    surface.columns = 3; surface.count = 5; surface.selectedIndex = 0
    surface.forceActiveFocus()
    commitSpy.clear(); cancelSpy.clear()
  }
  function test_arrow_navigation_and_partial_last_row() {
    keyClick(Qt.Key_Right); compare(surface.selectedIndex, 1)
    keyClick(Qt.Key_Right); compare(surface.selectedIndex, 2)
    keyClick(Qt.Key_Right); compare(surface.selectedIndex, 2)
    keyClick(Qt.Key_Down); compare(surface.selectedIndex, 4)
    keyClick(Qt.Key_Left); compare(surface.selectedIndex, 3)
    keyClick(Qt.Key_Left); compare(surface.selectedIndex, 3)
    keyClick(Qt.Key_Up); compare(surface.selectedIndex, 0)
    keyClick(Qt.Key_Up); compare(surface.selectedIndex, 0)
  }
  function test_explicit_activation_and_cancellation() {
    keyClick(Qt.Key_Return); compare(commitSpy.count, 1)
    keyClick(Qt.Key_Enter); compare(commitSpy.count, 2)
    keyClick(Qt.Key_Escape); compare(cancelSpy.count, 1)
  }
  function test_releasing_modifiers_does_not_commit() {
    keyRelease(Qt.Key_Control)
    keyRelease(Qt.Key_Alt)
    keyRelease(Qt.Key_Meta)
    compare(commitSpy.count, 0); compare(cancelSpy.count, 0)
  }
  function test_modified_arrows_and_enter_do_not_activate() {
    keyClick(Qt.Key_Right, Qt.ControlModifier)
    keyClick(Qt.Key_Return, Qt.AltModifier)
    compare(surface.selectedIndex, 0); compare(commitSpy.count, 0)
  }
  function test_empty_overview_navigation_is_safe() {
    surface.count = 0; surface.selectedIndex = -1
    keyClick(Qt.Key_Right); keyClick(Qt.Key_Down)
    compare(surface.selectedIndex, -1)
  }
}
