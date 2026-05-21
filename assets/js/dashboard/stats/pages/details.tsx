import React from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import { DetailsBreakdown } from '../modals/details-breakdown'
import Modal from '../modals/modal'

export function PagesDetails({
  breakdownReportKey
}: {
  breakdownReportKey: BreakdownReportKey
}) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportConfig = BREAKDOWN_REPORTS[breakdownReportKey]

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const metrics = chooseBreakdownMetricsByContext(
    reportConfig.metricsByContext,
    {
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: true,
      isRevenueAvailable: isRevenueAvailable
    }
  )

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        defaultOrderBy={[['visitors', 'desc']]}
        getExternalLinkUrl={reportConfig.getExternalLinkUrl}
      />
    </Modal>
  )
}
