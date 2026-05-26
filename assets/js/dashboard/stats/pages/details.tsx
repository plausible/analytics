import React from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  hasEventFilters,
  isRealTimeDashboard
} from '../../util/filters'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey,
  getExternalLinkUrlForPage
} from '../reports/reports-config'
import {
  DetailsBreakdown,
  DimensionCellProps
} from '../modals/details-breakdown'
import Modal from '../modals/modal'
import { rootRoute } from '../../router'
import { DrilldownLink } from '../../components/drilldown-link'
import { DetailsExternalLink } from './external-link'

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

  let metrics = chooseBreakdownMetricsByContext(reportConfig.metricsByContext, {
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRealtime: isRealTimeDashboard(dashboardState),
    isDetailed: true,
    isRevenueAvailable: isRevenueAvailable
  })

  if (metrics.includes('exit_rate') && hasEventFilters(dashboardState)) {
    metrics = metrics.filter((m) => m !== 'exit_rate')
  }

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        defaultOrderBy={[['visitors', 'desc']]}
        DimensionElement={PagesDimensionElement}
      />
    </Modal>
  )
}

const PagesDimensionElement = ({
  row,
  getFilterInfo,
  isActive
}: DimensionCellProps) => {
  const site = useSiteContext()
  return (
    <div className="break-all flex items-center gap-x-1">
      <DrilldownLink path={rootRoute.path} filterInfo={getFilterInfo(row)}>
        {row.dimensions[0]}
      </DrilldownLink>
      <DetailsExternalLink
        href={getExternalLinkUrlForPage(site, row)}
        isActive={isActive}
      />
    </div>
  )
}
