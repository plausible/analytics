import {
  getChangeInPercentagePoints,
  getRelativeChange
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
