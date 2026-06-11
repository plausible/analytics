import {
  AVERAGE_REVENUE_AS_AVERAGE_REVENUE,
  BOUNCE_RATE,
  CONVERSION_RATE_AS_CONVERSION_RATE,
  EVENTS_AS_TOTAL_CONVERSIONS,
  MetricSpec,
  PAGEVIEWS_AS_TOTAL_PAGEVIEWS,
  SCROLL_DEPTH,
  TIME_ON_PAGE,
  TOTAL_REVENUE_AS_TOTAL_REVENUE,
  VIEWS_PER_VISIT,
  VISIT_DURATION,
  VISITORS_AS_UNIQUE_CONVERSIONS,
  VISITORS_AS_UNIQUE_VISITORS,
  VISITS
} from '../metrics'
import {
  DashboardState,
  dashboardStateDefaultValue,
  Filter
} from '../../dashboard-state'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { PlausibleSite, siteContextDefaultValue } from '../../site-context'
import { StatsQuery } from '../../stats-query'
import { remapToApiFilters } from '../../util/filters'
import { StatsReportQueryKey } from '../../hooks/use-query-api'
import {
  getTopStatsMetrics,
  getTopStatsQuery,
  getPartialDayTimeRange,
  formatTopStatsData
} from './fetch-top-stats'

const aGoalFilter = ['is', 'goal', ['any goal']] as Filter
const aPageFilter = ['is', 'page', ['/any/page']] as Filter
const aPeriodNotRealtime = DashboardPeriod['28d']

const expectedBaseInclude: StatsQuery['include'] = {
  compare: ComparisonMode.previous_period,
  compare_match_day_of_week: true,
  imports: true,
  imports_meta: true,
  time_labels: false,
  partial_time_labels: false,
  empty_metrics: false,
  present_index: false
}

const expectedBaseQuery = {
  dimensions: [],
  filters: [],
  include: expectedBaseInclude,
  relative_date: null,
  order_by: null,
  pagination: null
}

type TestCase = [
  /** situation */
  string,
  /** input dashboard state & site state */
  Pick<DashboardState, 'filters' | 'period'> &
    Partial<{ site?: Pick<PlausibleSite, 'revenueGoals'> }>,
  /** expected metrics */
  MetricSpec[],
  /** expected top stats query */
  StatsQuery
]

const cases: TestCase[] = [
  [
    'realtime and goal filter',
    { period: DashboardPeriod.realtime, filters: [aGoalFilter] },
    [VISITORS_AS_UNIQUE_CONVERSIONS, EVENTS_AS_TOTAL_CONVERSIONS],
    {
      ...expectedBaseQuery,
      date_range: DashboardPeriod.realtime_30m,
      filters: remapToApiFilters([aGoalFilter]),
      include: { ...expectedBaseInclude, compare: null },
      metrics: ['visitors', 'events']
    }
  ],

  [
    'realtime',
    { period: DashboardPeriod.realtime, filters: [] },
    [VISITORS_AS_UNIQUE_VISITORS, PAGEVIEWS_AS_TOTAL_PAGEVIEWS],
    {
      ...expectedBaseQuery,
      date_range: DashboardPeriod.realtime_30m,
      include: {
        ...expectedBaseInclude,
        compare: null
      },
      metrics: ['visitors', 'pageviews']
    }
  ],

  [
    'goal filter with revenue metrics',
    {
      period: aPeriodNotRealtime,
      filters: [aGoalFilter],
      site: {
        revenueGoals: [{ display_name: 'a revenue goal', currency: 'USD' }]
      }
    },
    [
      VISITORS_AS_UNIQUE_CONVERSIONS,
      EVENTS_AS_TOTAL_CONVERSIONS,
      TOTAL_REVENUE_AS_TOTAL_REVENUE,
      AVERAGE_REVENUE_AS_AVERAGE_REVENUE,
      CONVERSION_RATE_AS_CONVERSION_RATE
    ],
    {
      ...expectedBaseQuery,
      date_range: aPeriodNotRealtime,
      filters: remapToApiFilters([aGoalFilter]),
      metrics: [
        'visitors',
        'events',
        'total_revenue',
        'average_revenue',
        'conversion_rate'
      ]
    }
  ],

  [
    'goal filter',
    { period: aPeriodNotRealtime, filters: [aGoalFilter] },
    [
      VISITORS_AS_UNIQUE_CONVERSIONS,
      EVENTS_AS_TOTAL_CONVERSIONS,
      CONVERSION_RATE_AS_CONVERSION_RATE
    ],
    {
      ...expectedBaseQuery,
      date_range: aPeriodNotRealtime,
      filters: remapToApiFilters([aGoalFilter]),
      metrics: ['visitors', 'events', 'conversion_rate']
    }
  ],

  [
    'page filter',
    {
      period: aPeriodNotRealtime,
      filters: [aPageFilter]
    },
    [
      VISITORS_AS_UNIQUE_VISITORS,
      VISITS,
      PAGEVIEWS_AS_TOTAL_PAGEVIEWS,
      BOUNCE_RATE,
      SCROLL_DEPTH,
      TIME_ON_PAGE
    ],
    {
      ...expectedBaseQuery,
      date_range: aPeriodNotRealtime,
      filters: remapToApiFilters([aPageFilter]),
      metrics: [
        'visitors',
        'visits',
        'pageviews',
        'bounce_rate',
        'scroll_depth',
        'time_on_page'
      ]
    }
  ],

  [
    'default',
    { period: aPeriodNotRealtime, filters: [] },
    [
      VISITORS_AS_UNIQUE_VISITORS,
      VISITS,
      PAGEVIEWS_AS_TOTAL_PAGEVIEWS,
      VIEWS_PER_VISIT,
      BOUNCE_RATE,
      VISIT_DURATION
    ],
    {
      ...expectedBaseQuery,
      date_range: aPeriodNotRealtime,
      metrics: [
        'visitors',
        'visits',
        'pageviews',
        'views_per_visit',
        'bounce_rate',
        'visit_duration'
      ]
    }
  ]
]

describe(`${getTopStatsMetrics.name}`, () => {
  test.each(
    cases.map(([name, inputDashboardState, expectedMetrics]) => [
      name,
      inputDashboardState,
      expectedMetrics
    ])
  )(
    'for %s dashboard, top stats metrics are as expected',
    (_, { site, ...inputDashboardState }, expectedMetrics) => {
      const dashboardState = {
        ...dashboardStateDefaultValue,
        resolvedFilters: inputDashboardState.filters,
        ...inputDashboardState
      }
      expect(
        getTopStatsMetrics(
          { ...siteContextDefaultValue, ...site },
          dashboardState
        )
      ).toEqual(expectedMetrics)
    }
  )
})

describe(`${getPartialDayTimeRange.name}`, () => {
  it('returns "until HH:MM" for today (partial day with current time as end)', () => {
    expect(
      getPartialDayTimeRange(['2024-01-13T00:00:00', '2024-01-13T14:32:00'])
    ).toBe('until 14:32')
  })

  it('returns "until HH:MM" when date strings include a timezone offset', () => {
    expect(
      getPartialDayTimeRange([
        '2026-01-19T00:00:00+00:00',
        '2026-01-19T14:32:00+00:00'
      ])
    ).toBe('until 14:32')
  })

  it('returns null for a full past day ending at 23:59:59', () => {
    expect(
      getPartialDayTimeRange(['2024-01-12T00:00:00', '2024-01-12T23:59:59'])
    ).toBeNull()
  })

  it('returns null when the date range spans multiple days', () => {
    expect(
      getPartialDayTimeRange(['2024-01-12T00:00:00', '2024-01-13T14:32:00'])
    ).toBeNull()
  })

  it('returns null when the end ISO has no time component', () => {
    expect(getPartialDayTimeRange(['2024-01-13', '2024-01-13'])).toBeNull()
  })
})

function makeTopStatsResponse(
  dateRange: [string, string],
  comparisonDateRange: [string, string] | null
) {
  return {
    query: {
      metrics: ['visitors'] as ['visitors'],
      dimensions: [],
      date_range: dateRange,
      comparison_date_range: comparisonDateRange as [string, string]
    },
    meta: {},
    results: [
      {
        metrics: [100],
        dimensions: [],
        comparison: { metrics: [80], change: [25] }
      }
    ],
    extraContext: {
      isRealtime: false,
      hasConversionGoalFilter: false,
      metrics: [VISITORS_AS_UNIQUE_VISITORS]
    }
  }
}

describe(`${formatTopStatsData.name}`, () => {
  it('sets comparisonTimeRange to "until HH:MM" when comparison period is also a partial day (Today vs Previous period)', () => {
    const response = makeTopStatsResponse(
      ['2026-04-21T00:00:00', '2026-04-21T10:25:00'],
      ['2026-04-20T00:00:00', '2026-04-20T10:25:00']
    )
    const { timeRange, comparisonTimeRange } = formatTopStatsData(response)
    expect(timeRange).toBe('until 10:25')
    expect(comparisonTimeRange).toBe('until 10:25')
  })

  it('sets comparisonTimeRange to null when comparison period is a full day (Today vs Custom period)', () => {
    const response = makeTopStatsResponse(
      ['2026-04-21T00:00:00', '2026-04-21T10:25:00'],
      ['2026-04-20T00:00:00', '2026-04-20T23:59:59']
    )
    const { timeRange, comparisonTimeRange } = formatTopStatsData(response)
    expect(timeRange).toBe('until 10:25')
    expect(comparisonTimeRange).toBeNull()
  })
})

describe(`${getTopStatsQuery.name}`, () => {
  test.each(cases)(
    'for %s dashboard, top stats query is as expected',
    (_, { site: _site, ...inputDashboardState }, metrics, expectedQuery) => {
      const dashboardState = {
        ...dashboardStateDefaultValue,
        resolvedFilters: inputDashboardState.filters,
        ...inputDashboardState
      }
      const queryKey: StatsReportQueryKey = [
        'top-stats',
        {
          dashboardState,
          reportParams: {
            metrics,
            dimensions: [],
            include: { imports_meta: true }
          }
        }
      ]
      expect(getTopStatsQuery(queryKey)).toEqual(expectedQuery)
    }
  )
})
