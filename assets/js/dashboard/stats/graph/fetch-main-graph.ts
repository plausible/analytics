import { Metric } from '../../../types/query-api'
import { DashboardState } from '../../dashboard-state'
import { DashboardPeriod } from '../../dashboard-time-periods'
import { PlausibleSite } from '../../site-context'
import { createStatsQuery } from '../../stats-query'
import { isRealTimeDashboard } from '../../util/filters'
import * as api from '../../api'

export function fetchMainGraph(
  site: PlausibleSite,
  dashboardState: DashboardState,
  metric: Metric,
  interval: string
): Promise<MainGraphResponse> {
  const metricToQuery =
    metric === 'conversion_rate' ? 'group_conversion_rate' : metric

  const reportParams = {
    metrics: [metricToQuery],
    dimensions: [`time:${interval}`],
    include: {
      time_labels: true,
      time_label_result_indices: true,
      present_index: true,
      partial_time_labels: true
    }
  }

  const statsQuery = createStatsQuery(dashboardState, reportParams)

  if (isRealTimeDashboard(dashboardState)) {
    statsQuery.date_range = DashboardPeriod.realtime_30m
  }

  statsQuery.include.present_index = true

  return api.stats(site, statsQuery)
}

type RevenueMetric = {
  short: string
  value: number
  long: string
  currency: string
}

type ResultItem = {
  dimensions: [string] // one item
  metrics: null | [number] | [RevenueMetric] // one item
}

export type MainGraphResponse = {
  results: Array<ResultItem | null>
  comparison_results: Array<
    (ResultItem & { change: [number | null] | null }) | null
  >
  meta: {
    partial_time_labels: string[] | null
    time_labels: string[]
    time_label_result_indices: (number | null)[]
    comparison_time_labels?: string[]
    comparison_time_label_result_indices?: (number | null)[]
  }
  query: {
    interval: string
    date_range: [string, string]
    comparison_date_range?: [string, string]
    dimensions: [string] // one item
    metrics: [string] // one item
  }
}
