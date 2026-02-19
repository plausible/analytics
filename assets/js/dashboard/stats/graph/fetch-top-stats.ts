import { Metric } from '../../../types/query-api'
import * as api from '../../api'
import { DashboardState } from '../../dashboard-state'
import {
  ComparisonMode,
  DashboardPeriod,
  isComparisonEnabled,
  isComparisonForbidden
} from '../../dashboard-time-periods'
import { PlausibleSite } from '../../site-context'
import { createStatsQuery, ReportParams, StatsQuery } from '../../stats-query'
import {
  hasConversionGoalFilter,
  hasPageFilter,
  isRealTimeDashboard
} from '../../util/filters'

export function topStatsQueries(
  dashboardState: DashboardState,
  metrics: MetricDef[]
): [StatsQuery, StatsQuery | null] {
  let currentVisitorsQuery = null

  console.log(dashboardState)

  if (isRealTimeDashboard(dashboardState)) {
    currentVisitorsQuery = createStatsQuery(dashboardState, {
      metrics: ['visitors']
    })

    currentVisitorsQuery.filters = []
  }
  const topStatsQuery = constructTopStatsQuery(dashboardState, metrics)

  return [topStatsQuery, currentVisitorsQuery]
}

export async function fetchTopStats(
  site: PlausibleSite,
  dashboardState: DashboardState
) {
  const metrics = chooseMetrics(site, dashboardState)
  const [topStatsQuery, currentVisitorsQuery] = topStatsQueries(
    dashboardState,
    metrics
  )
  const topStatsPromise = api.stats(site, topStatsQuery)

  const currentVisitorsPromise = currentVisitorsQuery
    ? api.stats(site, currentVisitorsQuery)
    : null

  const [topStatsResponse, currentVisitorsResponse] = await Promise.all([
    topStatsPromise,
    currentVisitorsPromise
  ])

  return formatTopStatsData(topStatsResponse, currentVisitorsResponse, metrics)
}

export type MetricDef = { key: Metric; label: string }

export function chooseMetrics(
  site: Pick<PlausibleSite, 'revenueGoals'>,
  dashboardState: DashboardState
): MetricDef[] {
  const revenueMetrics: MetricDef[] =
    site.revenueGoals.length > 0
      ? [
          { key: 'total_revenue', label: 'Total revenue' },
          { key: 'average_revenue', label: 'Average revenue' }
        ]
      : []

  if (
    isRealTimeDashboard(dashboardState) &&
    hasConversionGoalFilter(dashboardState)
  ) {
    return [
      { key: 'visitors', label: 'Unique conversions (last 30 min)' },
      { key: 'events', label: 'Total conversions (last 30 min)' }
    ]
  } else if (isRealTimeDashboard(dashboardState)) {
    return [
      { key: 'visitors', label: 'Unique visitors (last 30 min)' },
      { key: 'pageviews', label: 'Pageviews (last 30 min)' }
    ]
  } else if (hasConversionGoalFilter(dashboardState)) {
    return [
      { key: 'visitors', label: 'Unique conversions' },
      { key: 'events', label: 'Total conversions' },
      ...revenueMetrics,
      { key: 'conversion_rate', label: 'Conversion rate' }
    ]
  } else if (hasPageFilter(dashboardState)) {
    return [
      { key: 'visitors', label: 'Unique visitors' },
      { key: 'visits', label: 'Total visits' },
      { key: 'pageviews', label: 'Total pageviews' },
      { key: 'bounce_rate', label: 'Bounce rate' },
      { key: 'scroll_depth', label: 'Scroll depth' },
      { key: 'time_on_page', label: 'Time on page' }
    ]
  } else {
    return [
      { key: 'visitors', label: 'Unique visitors' },
      { key: 'visits', label: 'Total visits' },
      { key: 'pageviews', label: 'Total pageviews' },
      { key: 'views_per_visit', label: 'Views per visit' },
      { key: 'bounce_rate', label: 'Bounce rate' },
      { key: 'visit_duration', label: 'Visit duration' }
    ]
  }
}

function constructTopStatsQuery(
  dashboardState: DashboardState,
  metrics: MetricDef[]
): StatsQuery {
  const reportParams: ReportParams = {
    metrics: metrics.map((m) => m.key),
    include: { imports_meta: true }
  }

  const statsQuery = createStatsQuery(dashboardState, reportParams)

  if (
    !isComparisonEnabled(dashboardState.comparison) &&
    !isComparisonForbidden({
      period: dashboardState.period,
      segmentIsExpanded: false
    })
  ) {
    statsQuery.include.compare = ComparisonMode.previous_period
  }

  if (isRealTimeDashboard(dashboardState)) {
    statsQuery.date_range = DashboardPeriod.realtime_30m
  }

  return statsQuery
}

type TopStatItem = {
  metric: Metric
  value: number
  name: string
  graphable: boolean
  change?: number
  comparisonValue?: number
}

function formatTopStatsData(
  topStatsResponse: api.QueryApiResponse,
  currentVisitorsResponse: api.QueryApiResponse | null,
  metrics: MetricDef[]
) {
  const { query, meta, results } = topStatsResponse

  const topStats: TopStatItem[] = []

  if (currentVisitorsResponse) {
    topStats.push({
      metric: currentVisitorsResponse.query.metrics[0],
      value: currentVisitorsResponse.results[0].metrics[0],
      name: 'Current visitors',
      graphable: false
    })
  }

  for (let i = 0; i < query.metrics.length; i++) {
    const metricKey = query.metrics[i]
    const metricDef = metrics.find((m) => m.key === metricKey)

    if (!metricDef) {
      throw new Error('API response returned a metric that was not asked for')
    }

    topStats.push({
      metric: metricKey,
      value: results[0].metrics[i],
      name: metricDef.label,
      graphable: true,
      change: results[0].comparison?.change[i],
      comparisonValue: results[0].comparison?.metrics[i]
    })
  }

  const [from, to] = query.date_range.map((d) => d.split('T')[0])

  const comparingFrom = query.comparison_date_range
    ? query.comparison_date_range[0].split('T')[0]
    : null
  const comparingTo = query.comparison_date_range
    ? query.comparison_date_range[1].split('T')[0]
    : null

  return { topStats, meta, from, to, comparingFrom, comparingTo }
}
