import { DashboardState, Filter } from '../../dashboard-state'
import { calculateDashboardState } from '../../dashboard-state-context'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { PlausibleSite, siteContextDefaultValue } from '../../site-context'
import { StatsQuery } from '../../stats-query'
import { remapToApiFilters } from '../../util/filters'
import { chooseMetrics, MetricDef, topStatsQueries } from './fetch-top-stats'

const aGoalFilter = ['is', 'goal', ['any goal']] as Filter
const aPageFilter = ['is', 'page', ['/any/page']] as Filter
const aPeriodNotRealtime = DashboardPeriod['28d']

const expectedBaseInclude: StatsQuery['include'] = {
  compare: ComparisonMode.previous_period,
  compare_match_day_of_week: true,
  imports: true,
  imports_meta: true,
  time_labels: false
}

const expectedRealtimeVisitorsQuery: StatsQuery = {
  date_range: DashboardPeriod.realtime,
  dimensions: [],
  filters: [],
  include: { ...expectedBaseInclude, compare: null, imports_meta: false },
  metrics: ['visitors'],
  relative_date: null
}

type TestCase = [
  /** situation */
  string,
  /** input dashboard state & site state */
  Pick<DashboardState, 'filters' | 'period'> &
    Partial<
      Pick<DashboardState, 'with_imported'> & {
        site?: Pick<PlausibleSite, 'revenueGoals'>
      }
    >,
  /** expected metrics */
  MetricDef[],
  /** expected queries */
  [StatsQuery, null | StatsQuery]
]

const cases: TestCase[] = [
  [
    'realtime and goal filter',
    { period: DashboardPeriod.realtime, filters: [aGoalFilter] },
    [
      { key: 'visitors', label: 'Unique conversions (last 30 min)' },
      { key: 'events', label: 'Total conversions (last 30 min)' }
    ],
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
    [
      { key: 'visitors', label: 'Unique visitors (last 30 min)' },
      { key: 'pageviews', label: 'Total pageviews (last 30 min)' }
    ],
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
      { key: 'visitors', label: 'Unique conversions' },
      { key: 'events', label: 'Total conversions' },
      { key: 'total_revenue', label: 'Total revenue' },
      { key: 'average_revenue', label: 'Average revenue' },
      { key: 'conversion_rate', label: 'Conversion rate' }
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
    [
      { key: 'visitors', label: 'Unique conversions' },
      { key: 'events', label: 'Total conversions' },
      { key: 'conversion_rate', label: 'Conversion rate' }
    ],
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
    'page filter with imported data',
    { period: aPeriodNotRealtime, filters: [aPageFilter], with_imported: true },
    [
      { key: 'visitors', label: 'Unique visitors' },
      { key: 'visits', label: 'Total visits' },
      { key: 'pageviews', label: 'Total pageviews' },
      { key: 'scroll_depth', label: 'Scroll depth' }
    ],
    [
      {
        date_range: aPeriodNotRealtime,
        dimensions: [],
        filters: remapToApiFilters([aPageFilter]),
        include: expectedBaseInclude,
        metrics: ['visitors', 'visits', 'pageviews', 'scroll_depth'],
        relative_date: null
      },
      null
    ]
  ],

  [
    'page filter without imported data',
    {
      period: aPeriodNotRealtime,
      filters: [aPageFilter],
      with_imported: false
    },
    [
      { key: 'visitors', label: 'Unique visitors' },
      { key: 'visits', label: 'Total visits' },
      { key: 'pageviews', label: 'Total pageviews' },
      { key: 'bounce_rate', label: 'Bounce rate' },
      { key: 'scroll_depth', label: 'Scroll depth' },
      { key: 'time_on_page', label: 'Time on page' }
    ],

    [
      {
        date_range: aPeriodNotRealtime,
        dimensions: [],
        filters: remapToApiFilters([aPageFilter]),
        include: { ...expectedBaseInclude, imports: false },
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
      { key: 'visitors', label: 'Unique visitors' },
      { key: 'visits', label: 'Total visits' },
      { key: 'pageviews', label: 'Total pageviews' },
      { key: 'views_per_visit', label: 'Views per visit' },
      { key: 'bounce_rate', label: 'Bounce rate' },
      { key: 'visit_duration', label: 'Visit duration' }
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
    (_, { site, filters: rawFilters, ...parsedSearch }, expectedMetrics) => {
      const dashboardState = calculateDashboardState({
        parsedSearch: { ...parsedSearch, rawFilters },
        site: {
          domain: 'example.com',
          nativeStatsBegin: '2020-01-01',
          ...site
        },
        segments: [],
        segmentIsExpanded: false
      })
      expect(
        chooseMetrics({ ...siteContextDefaultValue, ...site }, dashboardState)
      ).toEqual(expectedMetrics)
    }
  )
})

describe(`${topStatsQueries.name}`, () => {
  test.each(cases)(
    'for %s dashboard, queries are as expected',
    (
      _,
      { site: _site, filters: rawFilters, ...parsedSearch },
      metrics,
      expectedQueries
    ) => {
      const dashboardState = calculateDashboardState({
        parsedSearch: { ...parsedSearch, rawFilters },
        site: {
          domain: 'example.com',
          nativeStatsBegin: '2020-01-01'
        },
        segments: [],
        segmentIsExpanded: false
      })
      const queries = topStatsQueries(dashboardState, metrics)
      expect(queries).toEqual(expectedQueries)
    }
  )
})
