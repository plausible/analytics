import React from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { defaultGetFilterInfo, getReferrerUrlFilterInfo } from '../breakdowns'
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
import { SourceFavicon } from './source-favicon'
import { DIRECT_NONE } from '.'
import { DetailsExternalLink } from '../pages/external-link'

type SourcesReportKey =
  | BreakdownReportKey.channels
  | BreakdownReportKey.sources
  | BreakdownReportKey.referrers
  | BreakdownReportKey.utmMediums
  | BreakdownReportKey.utmSources
  | BreakdownReportKey.utmCampaigns
  | BreakdownReportKey.utmContents
  | BreakdownReportKey.utmTerms

export function SourcesDetails({ reportKey }: { reportKey: SourcesReportKey }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportConfig = BREAKDOWN_REPORTS[reportKey]

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const metrics = reportConfig.getMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRealtime: isRealTimeDashboard(dashboardState),
    isDetailed: true,
    isRevenueAvailable: isRevenueAvailable
  })

  const DimensionElement =
    reportKey === BreakdownReportKey.sources
      ? SourcesDimensionCell
      : reportKey === BreakdownReportKey.referrers
        ? ReferrerUrlDimensionCell
        : SimpleDimensionCell

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        defaultOrderBy={[['visitors', 'desc']]}
        DimensionElement={DimensionElement}
      />
    </Modal>
  )
}

const SourcesDimensionCell = (props: DimensionCellProps) => {
  return (
    <DimensionCell
      icon={
        <SourceFavicon
          name={props.row.dimensions[0]}
          className="size-4 mr-2 align-middle inline"
        />
      }
      text={props.row.dimensions[0]}
      getFilterInfo={defaultGetFilterInfo}
      {...props}
    />
  )
}

const ReferrerUrlDimensionCell = (props: DimensionCellProps) => {
  const dimensionValue = props.row.dimensions[0]

  const externalUrl =
    dimensionValue === DIRECT_NONE ? null : `https://${dimensionValue}`

  return (
    <DimensionCell
      text={dimensionValue}
      icon={
        <SourceFavicon
          name={dimensionValue}
          className="size-4 mr-2 align-middle inline"
        />
      }
      externalLink={
        externalUrl && (
          <DetailsExternalLink href={externalUrl} isActive={props.isActive} />
        )
      }
      getFilterInfo={getReferrerUrlFilterInfo}
      {...props}
    />
  )
}

const SimpleDimensionCell = (props: DimensionCellProps) => {
  return (
    <DimensionCell
      text={props.row.dimensions[0]}
      getFilterInfo={defaultGetFilterInfo}
      {...props}
    />
  )
}
