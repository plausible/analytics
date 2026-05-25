import { Metric } from '../metrics'
import { DashboardPeriod } from '../../dashboard-time-periods'
import { useSiteContext } from '../../site-context'
import { createStatsQuery, StatsQuery } from '../../stats-query'
import { isRealTimeDashboard } from '../../util/filters'
import { MetricValue } from '../../api'
import * as api from '../../api'
import { Interval } from './intervals'
import { StatsReportQueryKey, useQueryApi } from '../../hooks/use-query-api'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { UseQueryResult } from '@tanstack/react-query'

export function useMainGraphQuery(
  metric: Metric,
  interval: Interval
): {
  apiState: UseQueryResult<MainGraphResponse>
  isRealtimeSilentUpdate: boolean
} {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const metricToQuery =
    metric === 'conversion_rate' ? 'group_conversion_rate' : metric

  const mainGraphQueryKey: StatsReportQueryKey = [
    'main-graph',
    {
      dashboardState,
      reportParams: {
        metrics: [metricToQuery],
        dimensions: [`time:${interval}`],
        include: {
          time_labels: true,
          partial_time_labels: true,
          empty_metrics: true,
          present_index: true
        }
      }
    }
  ]

  const { apiState, isRealtimeSilentUpdate } = useQueryApi<MainGraphResponse>(
    site,
    mainGraphQueryKey,
    { getStatsQuery: getMainGraphQuery }
  )

  return { apiState, isRealtimeSilentUpdate }
}

function getMainGraphQuery(queryKey: StatsReportQueryKey): StatsQuery {
  const [_reportId, keyOpts] = queryKey
  const { dashboardState, reportParams } = keyOpts
  const statsQuery = createStatsQuery(dashboardState, reportParams)

  if (isRealTimeDashboard(dashboardState)) {
    return { ...statsQuery, date_range: DashboardPeriod.realtime_30m }
  }

  return statsQuery
}

export type ResultItem = {
  dimensions: [string] // one item
  metrics: MetricValues
}

export type MetricValues = [MetricValue] // one item

export type MainGraphResponse = Pick<
  api.QueryApiResponse,
  'query' | 'extraContext'
> & {
  results: Array<ResultItem | null>
  comparison_results: Array<
    (ResultItem & { change: [number | null] | null }) | null
  >
  meta: {
    partial_time_labels: string[] | null
    comparison_partial_time_labels: string[] | null
    time_labels: string[]
    time_label_result_indices: (number | null)[]
    comparison_time_labels?: string[]
    comparison_time_label_result_indices?: (number | null)[]
    empty_metrics: MetricValues
    present_index: number
  }
}
