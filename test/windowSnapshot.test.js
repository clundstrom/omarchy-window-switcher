const assert = require('node:assert/strict')
const snapshot = require('../model/WindowSnapshot.js')

const current = {
  key: 'hyprland:0x1',
  toplevel: {},
  workspaceId: 1,
  workspaceName: '1',
  monitorId: 0,
  monitorName: 'DP-1',
  minimized: false,
  rect: { x: 0, y: 0, width: 960, height: 1080 },
  monitorRect: { x: 0, y: 0, width: 1920, height: 1080 }
}
function candidate(changes = {}) {
  return {
    ...current,
    rect: { ...current.rect },
    monitorRect: { ...current.monitorRect },
    ...changes
  }
}

for (const changes of [
  {},
  { title: 'A terminal progress title' },
  { sourceIndex: 7, focusHistoryID: 7 },
  { active: false, urgent: true, iconSource: 'unused', appName: 'unused' }
]) {
  const reused = snapshot.reconcile([current], [candidate(changes)])
  assert.equal(reused.changed, false, 'non-visual metadata does not destroy capture delegates')
  assert.equal(reused.records[0], current)
}

for (const changes of [
  { key: 'hyprland:0x2' },
  { toplevel: {} },
  { workspaceId: 2 },
  { workspaceName: 'Development' },
  { monitorId: 1 },
  { monitorName: 'DP-2' },
  { minimized: true },
  { rect: { ...current.rect, x: -320 } },
  { rect: { ...current.rect, width: 640 } },
  { rect: null },
  { monitorRect: { ...current.monitorRect, x: 1920 } },
  { monitorRect: { ...current.monitorRect, width: 2560 } },
  { monitorRect: null }
]) {
  const next = candidate(changes)
  const result = snapshot.reconcile([current], [next])
  assert.equal(result.changed, true, `${Object.keys(changes)[0]} invalidates stale preview state`)
  assert.equal(result.records[0], next)
}
assert.equal(snapshot.reconcile([current], []).changed, true, 'a closed source is removed')
assert.equal(snapshot.reconcile([], [current]).changed, true, 'a newly opened source is added')
const other = candidate({ key: 'hyprland:0x2', toplevel: {} })
assert.equal(snapshot.reconcile([current, other], [other, current]).changed, true,
  'changed stacking/order invalidates the snapshot')
assert.deepEqual(snapshot.reconcile([], []), { records: [], changed: false })
console.log('ok - workspace snapshots')
