import { Metric } from '../../../types/query-api'
import {
  DashboardState,
  dashboardStateDefaultValue,
  Filter
} from '../../dashboard-state'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { PlausibleSite, siteContextDefaultValue } from '../../site-context'
import { StatsQuery } from '../../stats-query'
import { remapToApiFilters } from '../../util/filters'
import { chooseMetrics, topStatsQueries } from './fetch-top-stats'

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

const expectedRealtimeVisitorsQuery: StatsQuery = {
  date_range: DashboardPeriod.realtime,
  dimensions: [],
  filters: [],
  include: {
    ...expectedBaseInclude,
    compare: null,
    imports_meta: false
  },
  metrics: ['visitors'],
  relative_date: null
}

type TestCase = [
  /** situation */
  string,
  /** input dashboard state & site state */
  Pick<DashboardState, 'filters' | 'period'> &
    Partial<{ site?: Pick<PlausibleSite, 'revenueGoals'> }>,
  /** expected metrics */
  Metric[],
  /** expected queries */
  [StatsQuery, null | StatsQuery]
]

const cases: TestCase[] = [
  [
    'realtime and goal filter',
    { period: DashboardPeriod.realtime, filters: [aGoalFilter] },
    ['visitors', 'events'],
    [
      {
        date_range: DashboardPeriod.realtime_30m,
        dimensions: [],
        filters: remapToApiFilters([aGoalFilter]),
        include: { ...expectedBaseInclude, compare: null },
        metrics: ['visitors', 'events'],
        relative_date: null
      },
      expectedRealtimeVisitorsQuery
    ]
  ],

  [
    'realtime',
    { period: DashboardPeriod.realtime, filters: [] },
    ['visitors', 'pageviews'],
    [
      {
        date_range: DashboardPeriod.realtime_30m,
        dimensions: [],
        filters: [],
        include: {
          ...expectedBaseInclude,
          compare: null
        },
        metrics: ['visitors', 'pageviews'],
        relative_date: null
      },
      expectedRealtimeVisitorsQuery
    ]
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
      'visitors',
      'events',
      'total_revenue',
      'average_revenue',
      'conversion_rate'
    ],
    [
      {
        date_range: aPeriodNotRealtime,
        dimensions: [],
        filters: remapToApiFilters([aGoalFilter]),
        include: expectedBaseInclude,
        metrics: [
          'visitors',
          'events',
          'total_revenue',
          'average_revenue',
          'conversion_rate'
        ],
        relative_date: null
      },
      null
    ]
  ],

  [
    'goal filter',
    { period: aPeriodNotRealtime, filters: [aGoalFilter] },
    ['visitors', 'events', 'conversion_rate'],
    [
      {
        date_range: aPeriodNotRealtime,
        dimensions: [],
        filters: remapToApiFilters([aGoalFilter]),
        include: expectedBaseInclude,
        metrics: ['visitors', 'events', 'conversion_rate'],
        relative_date: null
      },
      null
    ]
  ],

  [
    'page filter',
    {
      period: aPeriodNotRealtime,
      filters: [aPageFilter]
    },
    [
      'visitors',
      'visits',
      'pageviews',
      'bounce_rate',
      'scroll_depth',
      'time_on_page'
    ],

    [
      {
        date_range: aPeriodNotRealtime,
        dimensions: [],
        filters: remapToApiFilters([aPageFilter]),
        include: { ...expectedBaseInclude },
        metrics: [
          'visitors',
          'visits',
          'pageviews',
          'bounce_rate',
          'scroll_depth',
          'time_on_page'
        ],
        relative_date: null
      },
      null
    ]
  ],

  [
    'default',
    { period: aPeriodNotRealtime, filters: [] },
    [
      'visitors',
      'visits',
      'pageviews',
      'views_per_visit',
      'bounce_rate',
      'visit_duration'
    ],
    [
      {
        date_range: aPeriodNotRealtime,
        dimensions: [],
        filters: [],
        include: expectedBaseInclude,
        metrics: [
          'visitors',
          'visits',
          'pageviews',
          'views_per_visit',
          'bounce_rate',
          'visit_duration'
        ],
        relative_date: null
      },
      null
    ]
  ]
]

describe(`${chooseMetrics.name}`, () => {
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
        chooseMetrics({ ...siteContextDefaultValue, ...site }, dashboardState)
      ).toEqual(expectedMetrics)
    }
  )
})

describe(`${topStatsQueries.name}`, () => {
  test.each(cases)(
    'for %s dashboard, queries are as expected',
    (_, { site: _site, ...inputDashboardState }, metrics, expectedQueries) => {
      const dashboardState = {
        ...dashboardStateDefaultValue,
        resolvedFilters: inputDashboardState.filters,
        ...inputDashboardState
      }
      const queries = topStatsQueries(dashboardState, metrics)
      expect(queries).toEqual(expectedQueries)
    }
  )
})
