import * as api from '../../api'
import { DashboardState } from '../../dashboard-state'
import { getMetricLabel, Metric } from '../metrics'
import {
  ComparisonMode,
  DashboardPeriod,
  isComparisonEnabled,
  isComparisonForbidden
} from '../../dashboard-time-periods'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { createStatsQuery, StatsQuery } from '../../stats-query'
import {
  hasConversionGoalFilter,
  hasPageFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { StatsReportQueryKey, useQueryApi } from '../../hooks/use-query-api'
import { useDashboardStateContext } from '../../dashboard-state-context'

export function useTopStatsQuery() {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const topStatsQueryKey: StatsReportQueryKey = [
    'top-stats',
    {
      dashboardState,
      reportParams: {
        metrics: chooseMetrics(site, dashboardState),
        dimensions: [],
        include: { imports_meta: true }
      }
    }
  ]

  const { apiState, isRealtimeSilentUpdate } = useQueryApi(
    site,
    topStatsQueryKey,
    { getStatsQuery: getTopStatsQuery }
  )

  return { apiState, isRealtimeSilentUpdate }
}

export function getTopStatsQuery(queryKey: StatsReportQueryKey): StatsQuery {
  const [_reportId, keyOpts] = queryKey
  const { dashboardState, reportParams } = keyOpts

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

function getTopStatMetricLabel(
  metricKey: Metric,
  { isRealtime, hasConversionGoalFilter }: api.ExtraContext
) {
  const metricLabelSuffix = isRealtime ? ' (last 30 min)' : ''

  return `${getMetricLabel(metricKey, { hasConversionGoalFilter })}${metricLabelSuffix}`
}

type TopStatItem = {
  metric: Metric
  value: api.MetricValue
  name: string
  graphable: boolean
  change?: number
  comparisonValue?: number
}

export function formatTopStatsData(topStatsResponse: api.QueryApiResponse) {
  const { query, meta, results, extraContext } = topStatsResponse

  const topStats: TopStatItem[] = []

  for (let i = 0; i < query.metrics.length; i++) {
    const metricKey = query.metrics[i]
    topStats.push({
      metric: metricKey,
      value: results[0].metrics[i],
      name: getTopStatMetricLabel(metricKey, extraContext),
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
