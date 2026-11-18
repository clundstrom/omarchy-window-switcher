import QtQuick
import QtTest 1.3
import "../components" as Plugin

TestCase {
  name: "WorkspaceInput"
  when: windowShown
  width: 200
  height: 100
  Plugin.SwitcherKeySurface {
    id: surface
    anchors.fill: parent
    releaseArmed: true
    releaseActivation: false
  }
  SignalSpy { id: opacitySpy; target: surface; signalName: "transparencyToggled" }
  SignalSpy { id: cycleSpy; target: surface; signalName: "stepped" }
  SignalSpy { id: releaseSpy; target: surface; signalName: "modifierReleased" }
  function init() {
    surface.forceActiveFocus()
    surface.releaseActivation = false
    opacitySpy.clear(); cycleSpy.clear(); releaseSpy.clear()
  }
  function test_opacity_shortcut() {
    keyClick(Qt.Key_Backspace, Qt.MetaModifier)
    compare(opacitySpy.count, 1)
    compare(cycleSpy.count, 0)
  }
  function test_opacity_with_workspace_modifier() {
    keyClick(Qt.Key_Backspace, Qt.MetaModifier | Qt.AltModifier)
    compare(opacitySpy.count, 1)
  }
  function test_other_backspace_combinations() {
    keyClick(Qt.Key_Backspace)
    keyClick(Qt.Key_Backspace, Qt.ControlModifier | Qt.MetaModifier)
    keyClick(Qt.Key_Backspace, Qt.ShiftModifier | Qt.MetaModifier)
    compare(opacitySpy.count, 0)
  }
  function test_workspace_cycling() {
    keyClick(Qt.Key_Tab)
    keyClick(Qt.Key_Tab, Qt.ShiftModifier)
    compare(cycleSpy.count, 2)
    compare(opacitySpy.count, 0)
  }
  function test_secondary_modifier_release() {
    surface.releaseActivation = true
    // QtTest keyRelease synthesises releases for its modifier mask as well.
    // Supply the actual Wayland event combinations without those extra events.
    surface.handleModifierRelease({ key: Qt.Key_Alt, modifiers: Qt.MetaModifier, accepted: false })
    surface.handleModifierRelease({ key: Qt.Key_Meta, modifiers: Qt.AltModifier, accepted: false })
    compare(releaseSpy.count, 0)
    keyRelease(Qt.Key_Meta)
    compare(releaseSpy.count, 1)
  }
}
