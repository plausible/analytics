import React from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  hasEventFilters,
  isRealTimeDashboard
} from '../../util/filters'
import { defaultGetFilterInfo } from '../breakdowns'
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

  const metrics = reportConfig.getMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRealtime: isRealTimeDashboard(dashboardState),
    isDetailed: true,
    isRevenueAvailable: isRevenueAvailable,
    hasEventFilters: hasEventFilters(dashboardState)
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
