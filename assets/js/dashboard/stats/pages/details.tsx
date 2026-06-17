import React from 'react'
import { revenueAvailable, Filter } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  hasEventFilters,
  isRealTimeDashboard
} from '../../util/filters'
import { defaultGetFilterInfo, GetFilterInfo } from '../breakdowns'
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
import { externalLinkForPage, trimURL } from '../../util/url'

const MAX_DIMENSION_LENGTH = 70

function makeHostnameDimensionElement(pageFilterKey: string) {
  const getFilterInfo: GetFilterInfo = (_dim, row) => ({
    prefix: 'hostname',
    filter: ['is', 'hostname', [row.dimensions[0]]] as Filter,
    extraFilters: [
      {
        prefix: pageFilterKey,
        filter: ['is', pageFilterKey, [row.dimensions[1]]] as Filter
      }
    ]
  })
  return function HostnameDimensionElement(props: DimensionCellProps) {
    const site = useSiteContext()
    const hostname = props.row.dimensions[0]
    const path = props.row.dimensions[1]

    const displayValue = trimURL(
      `https://${hostname}${path}`,
      MAX_DIMENSION_LENGTH + 8
    ).replace(/^https:\/\//, '')

    return (
      <DimensionCell
        text={displayValue}
        externalLink={
          <DetailsExternalLink
            href={externalLinkForPage(site, path, hostname)}
            isActive={props.isActive}
          />
        }
        getFilterInfo={getFilterInfo}
        {...props}
      />
    )
  }
}

const HOSTNAME_DIMENSION_ELEMENTS: Partial<
  Record<BreakdownReportKey, (props: DimensionCellProps) => React.ReactNode>
> = {
  [BreakdownReportKey.pagesWithHostname]: makeHostnameDimensionElement('page'),
  [BreakdownReportKey.entryPagesWithHostname]:
    makeHostnameDimensionElement('entry_page'),
  [BreakdownReportKey.exitPagesWithHostname]:
    makeHostnameDimensionElement('exit_page')
}

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

  const DimensionElement =
    HOSTNAME_DIMENSION_ELEMENTS[breakdownReportKey] ?? PathDimensionElement

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        defaultOrderBy={[['visitors', 'desc']]}
        searchDimension={reportConfig.searchDimension}
        DimensionElement={DimensionElement}
      />
    </Modal>
  )
}

const PathDimensionElement = (props: DimensionCellProps) => {
  const site = useSiteContext()
  const path = props.row.dimensions[0]

  return (
    <DimensionCell
      text={path}
      externalLink={
        <DetailsExternalLink
          href={externalLinkForPage(site, path)}
          isActive={props.isActive}
        />
      }
      getFilterInfo={defaultGetFilterInfo}
      {...props}
    />
  )
}
