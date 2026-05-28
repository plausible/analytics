import React from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  hasEventFilters,
  isRealTimeDashboard
} from '../../util/filters'
import {
  chooseBreakdownMetricsByContext,
  defaultGetFilterInfo
} from '../breakdowns'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import {
  DetailsBreakdown,
  DimensionCell,
  DimensionCellProps
} from '../modals/details-breakdown'
import Modal from '../modals/modal'
import { DetailsExternalLink } from './external-link'
import { externalLinkForPage } from '../../util/url'

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

const PagesDimensionElement = (props: DimensionCellProps) => {
  const site = useSiteContext()
  return (
    <DimensionCell
      text={props.row.dimensions[0]}
      externalLink={
        <DetailsExternalLink
          href={externalLinkForPage(site, props.row.dimensions[0])}
          isActive={props.isActive}
        />
      }
      getFilterInfo={defaultGetFilterInfo}
      {...props}
    />
  )
}
