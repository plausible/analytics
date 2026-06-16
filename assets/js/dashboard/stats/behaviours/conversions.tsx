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
import { NonTimeDimension } from '../../stats-query'
import { FilterInfo } from '../../components/drilldown-link'
import { BEHAVIOURS_BAR_COLOR } from '.'
import { useSiteContext } from '../../site-context'

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
