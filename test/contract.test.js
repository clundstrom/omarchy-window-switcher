// Integration boundaries that model tests cannot exercise without a compositor.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const root = path.resolve(__dirname, '..')
const read = file => fs.readFileSync(path.join(root, file), 'utf8')
const manifest = JSON.parse(read('manifest.json'))
const switcher = read('Switcher.qml')
const card = read('components/WorkspaceCard.qml')
const grid = read('components/WorkspaceGridView.qml')
const keys = read('components/SwitcherKeySurface.qml')
const tap = read('components/WorkspaceTapTarget.qml')
const records = read('components/WindowRecords.qml')
const allQml = [switcher, ...fs.readdirSync(path.join(root, 'components'))
  .filter(name => name.endsWith('.qml')).map(name => read(`components/${name}`))].join('\n')

assert.equal(manifest.id, 'community.window-switcher', 'installed plugin identity remains compatible')
assert.equal(manifest.keepLoaded, true, 'workspace MRU survives closing the popup')
assert.deepEqual(manifest.kinds, ['overlay'])
assert.equal(manifest.entryPoints.overlay, 'Switcher.qml')
for (const name of ['next-workspace', 'previous-workspace', 'modifier-left', 'modifier-right']) {
  assert.ok(switcher.includes(`"${name}"`), `native shortcut ${name} is registered`)
}
for (const key of ['Qt.Key_Tab', 'Qt.Key_Backtab']) {
  assert.ok(keys.includes(key), `${key} remains available`)
}
assert.doesNotMatch(keys, /Qt\.Key_(?:Escape|Return|Enter|F2|Delete|[0-9])\b/,
  'removed navigation and cancellation controls stay removed')
assert.doesNotMatch(switcher, /onCancelled:|onCommitted:|onClicked:\s*root\.cancel\(/,
  'Enter, Escape and outside-click controls are removed')
assert.match(card, /ScreencopyView\s*\{/, 'previews use native compositor capture')
assert.match(card, /captureSource:\s*card\.captureEnabled/,
  'hidden/closed workspace cards detach their native sources')
assert.match(card, /live:\s*false/, 'workspace thumbnails do not stream in the background')
assert.doesNotMatch(card + switcher, /Behavior on opacity|NumberAnimation/,
  'the high-frequency workspace overlay has no QML fade')
assert.match(card, /constraintSize:/, 'capture requests are bounded to preview dimensions')
assert.doesNotMatch(card + grid + switcher + tap, /MouseArea\s*\{|HoverHandler\s*\{/,
  'click activation does not add pointer grabs or hover selection')
assert.match(tap, /acceptedButtons:\s*Qt\.LeftButton/, 'only the left mouse button activates a workspace')
assert.match(tap, /gesturePolicy:\s*TapHandler\.DragThreshold/, 'dragging cancels activation')
assert.match(switcher, /onWorkspaceActivated:[^\n]*root\.activateWorkspace/,
  'card activation reaches the controller by workspace identity')
assert.match(card, /textFormat:\s*Text\.PlainText/,
  'compositor-controlled labels cannot load rich-text resources')
assert.match(grid, /captureEnabled:[^\n]*switcherOpen[^\n]*inViewport/,
  'only visible workspace cards may capture')
assert.match(grid, /captureOffsets\[|offsets\[selectedIndex\]\s*=\s*0/,
  'the selected workspace participates in bounded capture scheduling')
assert.doesNotMatch(records, /DesktopEntries|appLibrary|iconSource|findDesktopEntry/,
  'preview enumeration does not scan application icons or desktop entries')
assert.doesNotMatch(allQml, /\bProcess\s*\{|\bXMLHttpRequest\b|https?:\/\/|grabToImage|execDetached|ShellRoot\s*\{/,
  'the plugin has no processes, network clients, disk capture, or second shell root')
assert.doesNotMatch(allQml, /SwitcherHeader\s*\{|WindowGridView\s*\{|GroupedListView\s*\{|TextInput\s*\{|CloseButton\s*\{/,
  'unused UI frameworks and alternate features are absent')
for (const file of ['SwitcherHeader.qml', 'WindowCard.qml', 'WindowGridView.qml', 'GroupedListView.qml']) {
  assert.equal(fs.existsSync(path.join(root, 'components', file)), false,
    `${file} is removed rather than merely hidden`)
}
assert.match(switcher, /!leftModifier\.pressed && !rightModifier\.pressed/,
  'modifier-release activation waits until both workspace modifiers have been released')
assert.match(switcher, /if \(root\.opened && root\.modifierTrackingSeen\) root\.finishModifierRelease\(\)/,
  'a release before layer focus is handled at opening')
assert.match(switcher, /root\.windows = \[\]/,
  'closed native capture records are discarded')
assert.match(switcher, /ShortcutInhibitor\s*\{[\s\S]*?enabled:\s*root\.opened/,
  'desktop gestures are inhibited only during the workspace interaction')
assert.equal((read('docs/bindings.lua').match(/dont_inhibit = true/g) || []).length, 4,
  'all four native switcher bindings remain usable during inhibition')
assert.match(keys, /Qt\.Key_Backspace[\s\S]*Qt\.MetaModifier/,
  'the focused overlay handles the standard opacity shortcut')
assert.match(switcher, /onModifierReleased:\s*root\.finishModifierRelease\(\)/,
  'secondary modifier release cannot commit while the workspace modifier remains held')
assert.match(card, /String\(card\.groupData\.id\)/,
  'workspace captions contain only the workspace number')
assert.ok(switcher.includes('appearance.windowTargets && /^[0-9a-fA-F]+$/.test(hexAddress)'),
  'window focus commands accept only validated compositor addresses')
assert.match(switcher, /if \(address\) Hyprland\.dispatch[\s\S]*else target\.activate\(\)/,
  'exact window focus is scoped to window targets and preserves workspace activation')
const appCard = read('components/ApplicationCard.qml')
assert.doesNotMatch(appCard, /ScreencopyView|WorkspaceCore|Process\s*\{/,
  'application icons do not create captures, native model instances or processes')
assert.match(appCard, /textFormat:\s*Text\.PlainText/,
  'application names are rendered as plain text')
assert.match(grid, /if \(presentation\.applicationMode\) return offsets/,
  'application mode schedules no native image captures')
assert.match(switcher, /applicationMetadata:\s*appearance\.applicationMode \? appMetadata : null/,
  'application lookups stay out of existing preview modes')
console.log('ok - workspace plugin boundaries')
