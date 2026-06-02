import React from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { defaultGetFilterInfo, getScreenFilterInfo } from '../breakdowns'
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
import { BrowserIcon, OsIcon, ScreenSizeIcon } from './icons'

type DevicesReportKey =
  | BreakdownReportKey.browsers
  | BreakdownReportKey.browserVersions
  | BreakdownReportKey.operatingSystems
  | BreakdownReportKey.operatingSystemVersions
  | BreakdownReportKey.screenSizes

export function DevicesDetails({
  reportKey,
  searchEnabled
}: {
  reportKey: DevicesReportKey
  searchEnabled?: boolean
}) {
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

  const DimensionElement = {
    [BreakdownReportKey.browsers]: BrowsersDimensionCell,
    [BreakdownReportKey.browserVersions]: BrowserVersionsDimensionCell,
    [BreakdownReportKey.operatingSystems]: OperatingSystemsDimensionCell,
    [BreakdownReportKey.operatingSystemVersions]:
      OperatingSystemVersionsDimensionCell,
    [BreakdownReportKey.screenSizes]: ScreenSizesDimensionCell
  }[reportKey]

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        defaultOrderBy={[['visitors', 'desc']]}
        searchEnabled={searchEnabled}
        DimensionElement={DimensionElement}
      />
    </Modal>
  )
}

const BrowsersDimensionCell = (props: DimensionCellProps) => (
  <DimensionCell
    {...props}
    getFilterInfo={defaultGetFilterInfo}
    text={props.row.dimensions[0]}
    icon={<BrowserIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const BrowserVersionsDimensionCell = (props: DimensionCellProps) => (
  <DimensionCell
    {...props}
    getFilterInfo={defaultGetFilterInfo}
    text={props.row.dimensions[0]}
    icon={<BrowserIcon dimensionValue={props.row.dimensions[1]} />}
  />
)

const OperatingSystemsDimensionCell = (props: DimensionCellProps) => (
  <DimensionCell
    {...props}
    getFilterInfo={defaultGetFilterInfo}
    text={props.row.dimensions[0]}
    icon={<OsIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const OperatingSystemVersionsDimensionCell = (props: DimensionCellProps) => (
  <DimensionCell
    {...props}
    getFilterInfo={defaultGetFilterInfo}
    text={props.row.dimensions[0]}
    icon={<OsIcon dimensionValue={props.row.dimensions[1]} />}
  />
)

const ScreenSizesDimensionCell = (props: DimensionCellProps) => (
  <DimensionCell
    getFilterInfo={getScreenFilterInfo}
    {...props}
    text={props.row.dimensions[0]}
    icon={<ScreenSizeIcon dimensionValue={props.row.dimensions[0]} />}
  />
)
