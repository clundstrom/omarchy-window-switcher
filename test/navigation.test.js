const assert = require('node:assert/strict')
const nav = require('../model/Navigation.js')

assert.equal(nav.wrappedIndex(0, 0), -1)
assert.equal(nav.wrappedIndex(-1, 5), 4)
assert.equal(nav.wrappedIndex(7, 5), 2)
assert.equal(nav.moveSequential(0, 1, 0), -1)
assert.equal(nav.moveSequential(0, -1, 1), 0)
assert.equal(nav.moveSequential(3, 1, 4), 0)
assert.equal(nav.moveSequential(0, -1, 4), 3)

for (const count of [1, 2, 5, 20]) {
  for (let index = 0; index < count; index++) {
    const next = nav.moveSequential(index, 1, count)
    assert.equal(nav.moveSequential(next, -1, count), index,
      'reverse cycling undoes forward cycling')
  }
  let selected = 0
  const visited = []
  for (let step = 0; step < count; step++) {
    visited.push(selected)
    selected = nav.moveSequential(selected, 1, count)
  }
  assert.equal(selected, 0)
  assert.equal(new Set(visited).size, count, 'one cycle visits every workspace exactly once')
}
console.log('ok - workspace navigation')
