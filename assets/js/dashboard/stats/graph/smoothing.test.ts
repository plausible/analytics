import { movingAverage } from './smoothing'

describe('movingAverage', () => {
  it('preserves the original series when smoothing is off', () => {
    const values = [0, 14, null, 7]
    expect(movingAverage(values, 'none')).toBe(values)
  })

  it.each(['7', '30'] as const)(
    'uses a trailing %s-bucket window, including zeros',
    (smoothing) => {
      const size = Number(smoothing)
      const values = [size, ...Array<number>(size).fill(0), size]
      const result = movingAverage(values, smoothing)
      expect(result[0]).toBe(size)
      expect(result[1]).toBe(size / 2)
      expect(result[size - 1]).toBe(1)
      expect(result[size]).toBe(0)
      expect(result[size + 1]).toBe(1)
      expect(values[0]).toBe(size)
    }
  )

  it('preserves missing buckets and restarts after a gap', () => {
    expect(movingAverage([null, 10, 20, null, 4, 8, null], '7')).toEqual([
      null,
      10,
      15,
      null,
      4,
      6,
      null
    ])
  })

  it('uses the available data for series shorter than the window', () => {
    expect(movingAverage([2, 4, 9], '30')).toEqual([2, 3, 5])
    expect(movingAverage([0.5, 1], '7')).toEqual([0.5, 0.75])
  })

  it('handles empty series', () => {
    expect(movingAverage([], '7')).toEqual([])
  })
})
