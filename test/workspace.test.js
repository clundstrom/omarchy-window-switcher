const assert = require('node:assert/strict')
const workspace = require('../model/WorkspaceModel.js')

// QVariantList is indexed like an Array, but Array.isArray returns false.
// This is the shape that caused all native geometry to be discarded in QML.
const qtPair = { 0: 12, 1: 38, length: 2 }
assert.equal(Array.isArray(qtPair), false)
assert.deepEqual(workspace.geometryPair(qtPair), [12, 38])
assert.deepEqual(workspace.geometryPair([3440, 1440]), [3440, 1440])
for (const invalid of [null, undefined, '12', [], [1], [null, 2], [1, NaN], [Infinity, 1], { 0: 1, 1: 2 }]) {
  assert.equal(workspace.geometryPair(invalid), null)
}

const monitor = { x: 0, y: 0, width: 3440, height: 1440 }
function window(rect, overrides = {}) {
  return { workspaceId: 3, workspaceName: '3', monitorRect: monitor, rect, ...overrides }
}

// Actual three-column workspace geometry from the running session. These
// unequal widths and gaps must survive; a generic 2x2 grouping is incorrect.
const threeColumns = [
  window({ x: 12, y: 38, width: 1373, height: 1390 }),
  window({ x: 1399, y: 38, width: 1005, height: 1390 }),
  window({ x: 2418, y: 38, width: 1010, height: 1390 })
]
const threeLayout = workspace.workspaceLayout(threeColumns)
assert.deepEqual(threeLayout.map(rect => rect.x), [12 / 3440, 1399 / 3440, 2418 / 3440])
assert.deepEqual(threeLayout.map(rect => rect.y), [38 / 1440, 38 / 1440, 38 / 1440])
assert.deepEqual(threeLayout.map(rect => rect.width), [1373 / 3440, 1005 / 3440, 1010 / 3440])
assert.ok(threeLayout.every(rect => !rect.hidden && rect.height === 1390 / 1440))

// Floating geometry stays over the tiled window instead of being tiled
// beside it. The caller preserves the compositor/MRU stacking order.
const floating = workspace.workspaceLayout([
  window({ x: 800, y: 300, width: 900, height: 500 }),
  window({ x: 12, y: 38, width: 3416, height: 1390 })
])
assert.equal(floating[0].x, 800 / 3440)
assert.equal(floating[0].y, 300 / 1440)
assert.ok(floating[0].x > floating[1].x && floating[0].width < floating[1].width)

// Scrolling layouts are a viewport, not a pack-to-fit arrangement. The QML
// workspace surface clips negative/offscreen coordinates and oversized
// windows. Never clamp x/y or resize every miniature to fit the monitor.
assert.deepEqual(workspace.normalizedRect(
  { x: -500, y: -100, width: 5000, height: 2000 }, monitor
), { x: -500 / 3440, y: -100 / 1440, width: 5000 / 3440, height: 2000 / 1440 })
assert.equal(workspace.normalizedRect({ x: 4000, y: 0, width: 1000, height: 1440 }, monitor).x, 4000 / 3440)
assert.equal(workspace.normalizedRect({ x: 1, y: 2, width: 5, height: 5 }, monitor).width, 5 / 3440)

// Monitor origin and logical dimensions are respected on secondary/scaled
// displays. No machine-specific resolution is embedded in normalization.
assert.deepEqual(workspace.normalizedRect(
  { x: 3700, y: 300, width: 960, height: 540 },
  { x: 3440, y: 120, width: 1920, height: 1080 }
), { x: 260 / 1920, y: 180 / 1080, width: 0.5, height: 0.5 })

for (const invalid of [null, { x: 0, y: 0, width: 0, height: 1 }, { x: NaN, y: 0, width: 1, height: 1 }]) {
  assert.equal(workspace.normalizedRect(invalid, monitor), null)
}
assert.equal(workspace.normalizedRect(threeColumns[0].rect, { width: Infinity, height: 1440 }), null)

// An incomplete/destroyed record must not force every known window into the
// fallback layout. Missing geometry becomes visible after the next snapshot.
const incomplete = workspace.workspaceLayout([threeColumns[0], window(null), null, window(null, { minimized: true })])
assert.equal(incomplete[0].x, 12 / 3440)
assert.equal(incomplete[0].width, 1373 / 3440)
assert.deepEqual(incomplete.slice(1).map(rect => rect.hidden), [true, true, true])
assert.deepEqual(workspace.workspaceLayout([]), [])
assert.equal(workspace.workspaceLayout([null])[0].hidden, true)
const fallback = workspace.workspaceLayout([window(null), window(null)])
assert.ok(fallback.every(rect => !rect.hidden && rect.width > 0))
assert.ok(fallback[1].x > fallback[0].x)

// Core workspace MRU semantics are preserved when the unused feature model
// is removed: regular occupied workspaces only, frozen recent order, stable
// window order within each workspace, and previous-workspace preselection.
const records = [
  window(null, { key: 'three-a' }),
  window(null, { key: 'one', workspaceId: 1, workspaceName: '1' }),
  window(null, { key: 'three-b' }),
  window(null, { key: 'special', workspaceId: -99, workspaceName: 'special:scratchpad' }),
  window(null, { key: 'minimized', minimized: true }),
  window(null, { key: 'unassociated', workspaceId: null })
]
const regular = workspace.regularWindows(records)
assert.deepEqual(regular.map(record => record.key), ['three-a', 'one', 'three-b'])
assert.deepEqual(workspace.noteWorkspaceMru(['1', '3', '1'], 3, 100), ['3', '1'])
assert.deepEqual(workspace.completeWorkspaceMru(['5'], regular, 2, 100), ['2', '5', '3', '1'])
assert.equal(workspace.previousWorkspaceKey(regular, 3, ['3', '9', '1']), '1')
const ordered = workspace.orderByWorkspace(regular, ['1', '3'])
assert.deepEqual(ordered.map(record => record.key), ['one', 'three-a', 'three-b'])
assert.deepEqual(workspace.groupWindows(ordered), [
  { key: '1', id: 1, label: 'Workspace 1', startIndex: 0, size: 1 },
  { key: '3', id: 3, label: 'Workspace 3', startIndex: 1, size: 2 }
])

console.log('ok - workspace geometry and MRU')
