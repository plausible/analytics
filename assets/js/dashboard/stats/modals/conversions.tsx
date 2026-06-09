import React from 'react'

import Modal from './modal'
import {
  DetailsBreakdown,
  DimensionCell,
  DimensionCellProps
} from './details-breakdown'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { QueryResultRow } from '../../api'
import { NonTimeDimension } from '../../stats-query'
import { FilterInfo } from '../../components/drilldown-link'

function ConversionsModal() {
  const { dashboardState } = useDashboardStateContext()

  const reportConfig = BREAKDOWN_REPORTS[BreakdownReportKey.goals]

  const baseMetrics = chooseBreakdownMetricsByContext(
    reportConfig.metricsByContext,
    {
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: true,
      isRevenueAvailable: false
    }
  )

  /*global BUILD_EXTRA*/
  const metrics = BUILD_EXTRA
    ? [...baseMetrics, 'average_revenue' as const, 'total_revenue' as const]
    : baseMetrics

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        defaultOrderBy={[['visitors', 'desc']]}
        DimensionElement={GoalsDimensionCell}
        hideMetricsIfAllNull={['total_revenue', 'average_revenue']}
      />
    </Modal>
  )
}

function GoalsDimensionCell(props: DimensionCellProps) {
  return (
    <DimensionCell
      {...props}
      text={props.row.dimensions[0]}
      getFilterInfo={getGoalsFilterInfo}
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

export default ConversionsModal
