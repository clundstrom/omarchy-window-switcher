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
assert.doesNotMatch(keys, /Qt\.Key_(?:Escape|Return|Enter|F2|Delete|[0-9])\b|Qt\.ControlModifier/,
  'the key surface contains only workspace switching controls')
assert.doesNotMatch(switcher, /onCancelled:|onCommitted:|onClicked:\s*root\.cancel\(/,
  'Enter, Escape and outside-click controls are removed')
assert.match(card, /ScreencopyView\s*\{/, 'previews use native compositor capture')
assert.match(card, /captureSource:\s*card\.captureEnabled/,
  'hidden/closed workspace cards detach their native sources')
assert.match(card, /live:\s*false/, 'workspace thumbnails do not stream in the background')
assert.doesNotMatch(card + switcher, /Behavior on opacity|NumberAnimation/,
  'the high-frequency workspace overlay has no QML fade')
assert.match(card, /constraintSize:/, 'capture requests are bounded to preview dimensions')
assert.match(card, /onClicked:\s*card\.activated\(\)/,
  'a left click activates the workspace card')
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
  'native activation waits until both workspace modifiers have been released')
assert.match(switcher, /if \(root\.opened && root\.modifierTrackingSeen\) root\.finishModifierRelease\(\)/,
  'a release before layer focus is handled at opening')
assert.match(switcher, /root\.windows = \[\]/,
  'closed native capture records are discarded')
console.log('ok - workspace plugin boundaries')
