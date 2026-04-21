import { Metric } from '../../../types/query-api'
import * as api from '../../api'
import { DashboardState } from '../../dashboard-state'
import { getMetricLabel } from '../metrics'
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
  metrics: Metric[]
): [StatsQuery, StatsQuery | null] {
  let currentVisitorsQuery = null

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

  const metricLabelSuffix = isRealTimeDashboard(dashboardState)
    ? ' (last 30 min)'
    : ''

  const formattedMetrics = metrics.map((key) => ({
    key,
    label: `${getMetricLabel(key, {
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
    })}${metricLabelSuffix}`
  }))

  return formatTopStatsData(
    topStatsResponse,
    currentVisitorsResponse,
    formattedMetrics
  )
}

export type MetricDef = { key: Metric; label: string }

export function chooseMetrics(
  site: Pick<PlausibleSite, 'revenueGoals'>,
  dashboardState: DashboardState
): Metric[] {
  const revenueMetrics: Metric[] =
    site.revenueGoals.length > 0 ? ['total_revenue', 'average_revenue'] : []

  if (
    isRealTimeDashboard(dashboardState) &&
    hasConversionGoalFilter(dashboardState)
  ) {
    return ['visitors', 'events']
  } else if (isRealTimeDashboard(dashboardState)) {
    return ['visitors', 'pageviews']
  } else if (hasConversionGoalFilter(dashboardState)) {
    return ['visitors', 'events', ...revenueMetrics, 'conversion_rate']
  } else if (hasPageFilter(dashboardState)) {
    return [
      'visitors',
      'visits',
      'pageviews',
      'bounce_rate',
      'scroll_depth',
      'time_on_page'
    ]
  } else {
    return [
      'visitors',
      'visits',
      'pageviews',
      'views_per_visit',
      'bounce_rate',
      'visit_duration'
    ]
  }
}

function constructTopStatsQuery(
  dashboardState: DashboardState,
  metrics: Metric[]
): StatsQuery {
  const reportParams: ReportParams = {
    metrics,
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

export function formatTopStatsData(
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

  const timeRange = getPartialDayTimeRange(query.date_range)

  const comparisonTimeRange = query.comparison_date_range
    ? getPartialDayTimeRange(query.comparison_date_range as [string, string])
    : null

  return {
    topStats,
    meta,
    from,
    to,
    comparingFrom,
    comparingTo,
    timeRange,
    comparisonTimeRange
  }
}

const END_OF_DAY = '23:59:59'

// Returns "until HH:MM" when the date range is a partial day (period=day for
// today, where the range is trimmed to the current time). Returns null otherwise.
export function getPartialDayTimeRange(
  dateRange: [string, string]
): string | null {
  const [startIso, endIso] = dateRange
  if (!endIso.includes('T')) return null

  const [startDate, endDate] = [startIso, endIso].map(
    (iso) => iso.split('T')[0]
  )
  if (startDate !== endDate) return null

  const endTime = endIso.split('T')[1]
  if (endTime.startsWith(END_OF_DAY)) return null

  return `until ${endTime.substring(0, 5)}`
}
