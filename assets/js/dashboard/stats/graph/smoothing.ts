export type GraphSmoothing = 'none' | '7' | '30'

/**
 * Trailing average of visible time buckets. Use the available buckets at the
 * start of a series and restart after gaps. Zero-valued buckets count toward
 * the window; nulls mark time buckets outside the series.
 */
export function movingAverage(
  values: (number | null)[],
  smoothing: GraphSmoothing
): (number | null)[] {
  if (smoothing === 'none') return values

  const window = Number(smoothing)
  let sum = 0
  let start = 0

  return values.map((value, index) => {
    if (value === null) {
      sum = 0
      start = index + 1
      return null
    }

    sum += value
    if (index - start >= window) {
      sum -= values[start]!
      start++
    }
    return sum / (index - start + 1)
  })
}
