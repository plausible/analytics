import {
  isSortable,
  getMetricLabel,
  getBreakdownMetricLabel,
  Metric
} from './metrics'

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

describe(`${getMetricLabel.name}`, () => {
  it.each([
    ['visitors', false, 'Unique visitors'],
    ['visitors', true, 'Unique conversions'],
    ['events', false, 'Total events'],
    ['events', true, 'Total conversions'],
    ['visits', false, 'Total visits'],
    ['pageviews', false, 'Total pageviews'],
    ['views_per_visit', false, 'Views per visit'],
    ['bounce_rate', false, 'Bounce rate'],
    ['visit_duration', false, 'Visit duration'],
    ['time_on_page', false, 'Time on page'],
    ['scroll_depth', false, 'Scroll depth'],
    ['conversion_rate', false, 'Conversion rate'],
    ['total_revenue', false, 'Total revenue'],
    ['average_revenue', false, 'Average revenue'],
    ['percentage', false, 'Percentage'],
    ['group_conversion_rate', false, 'Conversion rate'],
    ['total_visitors', false, 'Total visitors'],
    ['exit_rate', false, 'Exit rate']
  ] as const)(
    '%s (hasConversionGoalFilter=%s) -> %s',
    (metric, hasConversionGoalFilter, expected) => {
      expect(getMetricLabel(metric, { hasConversionGoalFilter })).toBe(expected)
    }
  )
})

describe(`${getBreakdownMetricLabel.name}`, () => {
  const defaults = { hasConversionGoalFilter: false, isRealtime: false }

  describe('entry page dimension', () => {
    const dimension = 'visit:entry_page'

    it('returns Unique entrances for visitors (no goal, not realtime)', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Unique entrances')
    })

    it('returns Total entrances for visits (no goal, not realtime)', () => {
      expect(
        getBreakdownMetricLabel('visits', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Total entrances')
    })

    it('falls back to default label for visitors with conversion goal', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          hasConversionGoalFilter: true,
          isRealtime: false,
          dimensions: [dimension]
        })
      ).toBe('Conversions')
    })

    it('falls back to default label for visitors in realtime', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          hasConversionGoalFilter: false,
          isRealtime: true,
          dimensions: [dimension]
        })
      ).toBe('Current visitors')
    })

    it('falls back to default label for other metrics', () => {
      expect(
        getBreakdownMetricLabel('bounce_rate', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Bounce rate')
    })
  })

  describe('exit page dimension', () => {
    const dimension = 'visit:exit_page'

    it('returns Unique exits for visitors (no goal, not realtime)', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Unique exits')
    })

    it('returns Total exits for visits (no goal, not realtime)', () => {
      expect(
        getBreakdownMetricLabel('visits', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Total exits')
    })

    it('falls back to default label for visitors with conversion goal', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          hasConversionGoalFilter: true,
          isRealtime: false,
          dimensions: [dimension]
        })
      ).toBe('Conversions')
    })

    it('falls back to default label for visitors in realtime', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          hasConversionGoalFilter: false,
          isRealtime: true,
          dimensions: [dimension]
        })
      ).toBe('Current visitors')
    })

    it('falls back to default label for other metrics', () => {
      expect(
        getBreakdownMetricLabel('exit_rate', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Exit rate')
    })
  })

  describe('goal dimension', () => {
    const dimension = 'event:goal'

    it('returns Uniques for visitors', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Uniques')
    })

    it('returns Total for events', () => {
      expect(
        getBreakdownMetricLabel('events', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Total')
    })

    it('returns CR for conversion_rate', () => {
      expect(
        getBreakdownMetricLabel('conversion_rate', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('CR')
    })

    it('falls back to default label for other metrics', () => {
      expect(
        getBreakdownMetricLabel('bounce_rate', {
          ...defaults,
          dimensions: [dimension]
        })
      ).toBe('Bounce rate')
    })
  })

  describe('any other session dimension', () => {
    const dimensions = ['visit:source']

    it('returns Visitors for visitors (no goal, not realtime)', () => {
      expect(
        getBreakdownMetricLabel('visitors', { ...defaults, dimensions })
      ).toBe('Visitors')
    })

    it('returns Conversions for visitors with conversion goal', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          hasConversionGoalFilter: true,
          isRealtime: false,
          dimensions
        })
      ).toBe('Conversions')
    })

    it('returns Current visitors for visitors in realtime', () => {
      expect(
        getBreakdownMetricLabel('visitors', {
          hasConversionGoalFilter: false,
          isRealtime: true,
          dimensions
        })
      ).toBe('Current visitors')
    })

    it.each([
      ['group_conversion_rate', 'CR'],
      ['conversion_rate', 'CR'],
      ['pageviews', 'Pageviews'],
      ['average_revenue', 'Average'],
      ['total_revenue', 'Revenue']
    ] as const)('%s -> %s', (metric, expected) => {
      expect(getBreakdownMetricLabel(metric, { ...defaults, dimensions })).toBe(
        expected
      )
    })

    it.each([
      'visits',
      'views_per_visit',
      'bounce_rate',
      'visit_duration'
    ] as const)('delegates to getMetricLabel for %s', (metric) => {
      expect(getBreakdownMetricLabel(metric, { ...defaults, dimensions })).toBe(
        getMetricLabel(metric, defaults)
      )
    })
  })
})
