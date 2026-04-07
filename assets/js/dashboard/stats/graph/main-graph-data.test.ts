import {
  getDefaultRevenueMetricValue,
  getChangeInPercentagePoints,
  getRelativeChange,
  getLineSegments
} from './main-graph-data'

describe(`${getDefaultRevenueMetricValue.name}`, () => {
  it('makes a unitless guess for situation with no sample revenue item', () => {
    expect(getDefaultRevenueMetricValue()).toEqual({
      short: '0.0',
      value: 0.0,
      long: '0.00',
      currency: ''
    })
  })

  it('handles sample dollar item', () => {
    const sample = {
      short: '$1.1K',
      value: 1076.0,
      long: '$1,076.00',
      currency: 'USD'
    }
    expect(getDefaultRevenueMetricValue(sample)).toEqual({
      short: '$0.0',
      value: 0.0,
      long: '$0.00',
      currency: 'USD'
    })
  })
})

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

const np = (value = 0) => ({
  mainSeriesDefined: true,
  value,
  isPartial: false,
  timeLabel: ''
})
const p = (value = 0) => ({
  mainSeriesDefined: true,
  value,
  isPartial: true,
  timeLabel: ''
})
const gap = () => ({ mainSeriesDefined: false }) as const

describe(`${getLineSegments.name}`, () => {
  it('returns empty for empty input', () => {
    expect(getLineSegments([])).toEqual([])
  })

  it('returns empty for a single point (no edge to draw)', () => {
    expect(getLineSegments([np()])).toEqual([])
  })

  it('returns empty for a single gap', () => {
    expect(getLineSegments([gap()])).toEqual([])
  })

  it('returns a full segment for two non-partial points', () => {
    expect(getLineSegments([np(), np()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'full' }
    ])
  })

  it('returns a partial segment for two partial points', () => {
    expect(getLineSegments([p(), p()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'partial' }
    ])
  })

  it('returns partial when connecting non-partial to partial', () => {
    expect(getLineSegments([np(), p()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'partial' }
    ])
  })

  it('returns partial when connecting partial to non-partial', () => {
    expect(getLineSegments([p(), np()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'partial' }
    ])
  })

  it('handles single full period in the middle of two partial periods', () => {
    expect(getLineSegments([p(), np(), p()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 3, type: 'partial' }
    ])
  })

  it('handles partial periods on both ends', () => {
    expect(getLineSegments([p(), np(), np(), p()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'partial' },
      { startIndexInclusive: 1, stopIndexExclusive: 3, type: 'full' },
      { startIndexInclusive: 2, stopIndexExclusive: 4, type: 'partial' }
    ])
  })

  it('handles leading gaps', () => {
    expect(
      getLineSegments([gap(), gap(), np(), np(), np(), np(), p()])
    ).toEqual([
      { startIndexInclusive: 2, stopIndexExclusive: 6, type: 'full' },
      { startIndexInclusive: 5, stopIndexExclusive: 7, type: 'partial' }
    ])
  })

  it('handles trailing gaps', () => {
    expect(getLineSegments([np(), np(), p(), gap(), gap()])).toEqual([
      { startIndexInclusive: 0, stopIndexExclusive: 2, type: 'full' },
      { startIndexInclusive: 1, stopIndexExclusive: 3, type: 'partial' }
    ])
  })
})
