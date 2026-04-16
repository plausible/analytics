import {
  getChangeInPercentagePoints,
  getRelativeChange,
  getLineSegments
} from './main-graph-data'

describe(`${getChangeInPercentagePoints.name}`, () => {
  it('returns the difference', () => {
    expect(getChangeInPercentagePoints(70, 60)).toBe(10)
  })

  it('returns a negative value when value is lower', () => {
    expect(getChangeInPercentagePoints(30, 50)).toBe(-20)
  })

  it('returns 0 when both values are equal', () => {
    expect(getChangeInPercentagePoints(5, 5)).toBe(0)
  })
})

describe(`${getRelativeChange.name}`, () => {
  it('returns the percentage change rounded to nearest integer', () => {
    expect(getRelativeChange(150, 100)).toBe(50)
  })

  it('rounds fractional percentages', () => {
    expect(getRelativeChange(10, 3)).toBe(233) // (10-3)/3*100 = 233.33...
  })

  it('returns 100 when comparison is 0 and value is positive', () => {
    expect(getRelativeChange(5, 0)).toBe(100)
  })

  it('returns 0 when both are 0', () => {
    expect(getRelativeChange(0, 0)).toBe(0)
  })

  it('returns a negative value for a decrease', () => {
    expect(getRelativeChange(50, 100)).toBe(-50)
  })
})

const seriesValueBase = {
  numericValue: 0,
  value: 0,
  timeLabel: ''
}

// not current
const nc = () => ({
  isCurrent: false,
  isPartial: false,
  isDefined: true,
  ...seriesValueBase
})
// current
const c = () => ({
  isCurrent: true,
  isPartial: false,
  isDefined: true,
  ...seriesValueBase
})
const gap = () => ({ isDefined: false }) as const

describe(`${getLineSegments.name}`, () => {
  it('returns empty for empty input', () => {
    expect(getLineSegments([])).toEqual([])
  })

  it('returns empty for a single point (no edge to draw)', () => {
    expect(getLineSegments([nc()])).toEqual([])
  })

  it('returns empty for a single gap', () => {
    expect(getLineSegments([gap()])).toEqual([])
  })

  it('returns a full segment for two points', () => {
    expect(getLineSegments([nc(), nc()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'full' }
    ])
  })

  it('returns a current segment when connecting to current point', () => {
    expect(getLineSegments([nc(), c()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'current' }
    ])
  })

  it('handles more points when the last point is current', () => {
    expect(getLineSegments([nc(), nc(), nc(), c()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 3, type: 'full' },
      { startIndexInclusive: 2, stopIndexExclusive: 4, type: 'current' }
    ])
  })

  it('handles leading gaps', () => {
    expect(
      getLineSegments([gap(), gap(), nc(), nc(), nc(), nc(), c()])
    ).toEqual([
      { startIndexInclusive: 2, stopIndexExclusive: 6, type: 'full' },
      { startIndexInclusive: 5, stopIndexExclusive: 7, type: 'current' }
    ])
  })

  it('handles trailing gaps', () => {
    expect(getLineSegments([nc(), nc(), nc(), gap(), gap()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 3, type: 'full' }
    ])
  })
})
