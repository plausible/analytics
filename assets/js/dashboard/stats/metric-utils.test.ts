import { isSortable } from './metric-utils'
import { Metric } from './metrics'

describe(`${isSortable.name}`, () => {
  it('returns false for total_visitors', () => {
    expect(isSortable('total_visitors')).toBe(false)
  })

  const sortableMetrics: Metric[] = [
    'visitors',
    'visits',
    'pageviews',
    'views_per_visit',
    'bounce_rate',
    'visit_duration',
    'events',
    'percentage',
    'conversion_rate',
    'group_conversion_rate',
    'time_on_page',
    'total_revenue',
    'average_revenue',
    'scroll_depth',
    'exit_rate'
  ]

  it.each(sortableMetrics)('returns true for %s', (metric) => {
    expect(isSortable(metric)).toBe(true)
  })
})
