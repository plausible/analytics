import React, { ReactNode, useCallback } from 'react'

import {
  DimensionCellWithBar,
  DimensionCellWithBarProps,
  IndexBreakdown
} from '../reports/index-breakdown'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import { QueryApiResponse, QueryResultRow } from '../../api'
import { NonTimeDimension, StatsQuery } from '../../stats-query'
import { FilterInfo } from '../../components/drilldown-link'
import {
  BEHAVIOURS_BAR_COLOR,
  BEHAVIOURS_METRIC_COLUMN_WIDTH,
  BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE
} from '.'
import { useSiteContext } from '../../site-context'
import {
  defaultGetStatsQuery,
  StatsReportQueryKey
} from '../../hooks/use-query-api'
import { DashboardPeriod } from '../../dashboard-time-periods'

export function getConversionsStatsQuery(
  queryKey: StatsReportQueryKey
): StatsQuery {
  const statsQuery = defaultGetStatsQuery(queryKey)
  if (statsQuery.date_range === DashboardPeriod.realtime) {
    return { ...statsQuery, date_range: DashboardPeriod.realtime_30m }
  }
  return statsQuery
}

type ConversionsProps = {
  onDataReady?: (data: QueryApiResponse) => void
  onGoalFilterClick?: (goalName: string) => void
}

export default function Conversions({
  onDataReady,
  onGoalFilterClick
}: ConversionsProps): ReactNode {
  const site = useSiteContext()
  const reportConfig = BREAKDOWN_REPORTS[BreakdownReportKey.goals]

  /*global BUILD_EXTRA*/
  const metrics = reportConfig.getMetrics({
    isRevenueAvailable: BUILD_EXTRA && site.revenueGoals.length > 0
  })

  const DimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => {
      const goalName = props.row.dimensions[0]
      return (
        <DimensionCellWithBar
          {...props}
          barClassName={BEHAVIOURS_BAR_COLOR}
          text={goalName}
          getFilterInfo={getGoalsFilterInfo}
          onClick={() => onGoalFilterClick && onGoalFilterClick(goalName)}
        />
      )
    },
    [onGoalFilterClick]
  )

  return (
    <IndexBreakdown
      metrics={metrics}
      dimensions={reportConfig.dimensions}
      dimensionLabel={reportConfig.dimensionLabel}
      alwaysOnFilters={reportConfig.alwaysOnFilters}
      DimensionElement={DimensionElement}
      onDataReady={onDataReady}
      hideMetricsIfAllNull={['total_revenue', 'average_revenue']}
      hideMetricsOnMobile={BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE}
      metricColumnWidth={BEHAVIOURS_METRIC_COLUMN_WIDTH}
      getStatsQuery={getConversionsStatsQuery}
    />
  )
}

export function getGoalsFilterInfo(
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo {
  const goalName = row.dimensions[0]
  return {
    prefix: 'goal',
    filter: ['is', 'goal', [goalName]]
  }
}
