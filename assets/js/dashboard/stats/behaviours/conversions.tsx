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
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { QueryApiResponse, QueryResultRow } from '../../api'
import { NonTimeDimension } from '../../stats-query'
import { FilterInfo } from '../../components/drilldown-link'

const BAR_COLOR = 'bg-red-50 group-hover/row:bg-red-100'

type ConversionsProps = {
  afterFetchData?: (data: QueryApiResponse) => void
  onGoalFilterClick?: (goalName: string) => void
}

export default function Conversions({
  afterFetchData,
  onGoalFilterClick
}: ConversionsProps): ReactNode {
  const { dashboardState } = useDashboardStateContext()
  const reportConfig = BREAKDOWN_REPORTS[BreakdownReportKey.goals]

  const baseMetrics = chooseBreakdownMetricsByContext(
    reportConfig.metricsByContext,
    {
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: false,
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRevenueAvailable: false
    }
  )

  /*global BUILD_EXTRA*/
  const metrics = BUILD_EXTRA
    ? [...baseMetrics, 'total_revenue' as const, 'average_revenue' as const]
    : baseMetrics

  const DimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => {
      const goalName = props.row.dimensions[0]
      return (
        <DimensionCellWithBar
          {...props}
          barClassName={BAR_COLOR}
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
      onDataReady={afterFetchData}
      hideMetricsIfAllNull={['total_revenue', 'average_revenue']}
    />
  )
}

function getGoalsFilterInfo(
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo {
  const goalName = row.dimensions[0]
  return {
    prefix: 'goal',
    filter: ['is', 'goal', [goalName]]
  }
}
