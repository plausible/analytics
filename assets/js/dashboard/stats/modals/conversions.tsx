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
import {
  getConversionsStatsQuery,
  getGoalsFilterInfo
} from '../behaviours/conversions'
import { useSiteContext } from '../../site-context'

function ConversionsModal() {
  const site = useSiteContext()

  const reportConfig = BREAKDOWN_REPORTS[BreakdownReportKey.goals]

  /*global BUILD_EXTRA*/
  const metrics = reportConfig.getMetrics({
    isRevenueAvailable: BUILD_EXTRA && site.revenueGoals.length > 0
  })

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
        getStatsQuery={getConversionsStatsQuery}
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

export default ConversionsModal
