import { Metric } from '../metrics'
import { DashboardState } from '../../dashboard-state'
import { DashboardPeriod } from '../../dashboard-time-periods'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { createStatsQuery, ReportParams, StatsQuery } from '../../stats-query'
import { isRealTimeDashboard } from '../../util/filters'
import { MetricValue } from '../../api'
import * as api from '../../api'
import { Interval } from './intervals'
import { StatsReportQueryKey, useQueryApi } from '../../hooks/use-query-api'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useMemo } from 'react'
import { UseQueryResult } from '@tanstack/react-query'

export function useMainGraphQuery(
  metric: Metric | null,
  interval: Interval
): {
  apiState: UseQueryResult<MainGraphResponse>
  isRealtimeSilentUpdate: boolean
} {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const mainGraphQueryKey = useMemo((): StatsReportQueryKey => {
    return [
      'main-graph',
      {
        dashboardState,
        reportParams: {
          // Should default to visitors if metric is null? Currently possibly invalid
          // query with `metrics: [null]` which will never run due to `enabled: false`
          metrics: [metric!],
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
  }, [dashboardState, metric, interval])

  const { apiState, isRealtimeSilentUpdate } = useQueryApi<MainGraphResponse>(
    site,
    mainGraphQueryKey,
    {
      getStatsQuery: getMainGraphQuery,
      enabled: !!metric
    }
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

export function fetchMainGraph(
  site: PlausibleSite,
  dashboardState: DashboardState,
  metric: Metric,
  interval: Interval
): Promise<MainGraphResponse> {
  const metricToQuery =
    metric === 'conversion_rate' ? 'group_conversion_rate' : metric

  const reportParams: ReportParams = {
    metrics: [metricToQuery],
    dimensions: [`time:${interval}`],
    include: {
      time_labels: true,
      partial_time_labels: true,
      empty_metrics: true,
      present_index: true
    }
  }

  const statsQuery = createStatsQuery(dashboardState, reportParams)

  if (isRealTimeDashboard(dashboardState)) {
    statsQuery.date_range = DashboardPeriod.realtime_30m
  }

  return api.stats(site, statsQuery)
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
