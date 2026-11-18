// Sequential cycling only.

function wrappedIndex(index, count) {
  var total = Math.max(0, Number(count) || 0)
  if (total === 0) return -1
  var value = Number(index) || 0
  return ((value % total) + total) % total
}

function moveSequential(index, direction, count) {
  return wrappedIndex((Number(index) || 0) + (Number(direction) < 0 ? -1 : 1), count)
}

if (typeof module !== "undefined") module.exports = { wrappedIndex: wrappedIndex, moveSequential: moveSequential }
