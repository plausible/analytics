import { getSuggestedXTickValues, getXDomain } from './graph'
import * as d3 from 'd3'

describe(`${getXDomain.name}`, () => {
  it('returns [0, 1] for a single bucket to avoid a zero-width domain', () => {
    expect(getXDomain(1)).toEqual([0, 1])
  })
  it('returns [0, bucketCount - 1] for multiple buckets', () => {
    expect(getXDomain(5)).toEqual([0, 4])
  })
})

const anyRange = [0, 100]
describe(`${getSuggestedXTickValues.name}`, () => {
  it('handles 1 bucket', () => {
    const data = new Array(1).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([[0, 1]])
  })

  it('handles 2 buckets', () => {
    const data = new Array(2).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([[0, 1]])
  })

  it('handles 7 buckets', () => {
    const data = new Array(7).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([
      [0, 1, 2, 3, 4, 5, 6],
      [0, 2, 4, 6],
      [0, 5]
    ])
  })

  it('handles 24 buckets (day by hours)', () => {
    const data = new Array(24).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([
      [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22],
      [0, 5, 10, 15, 20],
      [0, 10, 20],
      [0, 20]
    ])
  })

  it('handles 28 buckets', () => {
    const data = new Array(28).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([
      [0, 5, 10, 15, 20, 25],
      [0, 10, 20],
      [0, 20]
    ])
  })

  it('handles 91 buckets', () => {
    const data = new Array(91).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([
      [0, 10, 20, 30, 40, 50, 60, 70, 80, 90],
      [0, 20, 40, 60, 80],
      [0, 50],
      [0]
    ])
  })

  it('handles 700 buckets', () => {
    const data = new Array(700).fill(0)
    expect(
      getSuggestedXTickValues(
        d3.scaleLinear(getXDomain(data.length), anyRange),
        data.length
      )
    ).toEqual([
      [0, 100, 200, 300, 400, 500, 600],
      [0, 200, 400, 600],
      [0, 500]
    ])
  })
})
