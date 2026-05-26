import React, { useState } from 'react'

import * as storage from '../../util/storage'
import {
  hasConversionGoalFilter,
  isFilteringOnFixedValue,
  isRealTimeDashboard
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'
import { QueryApiResponse, QueryResultRow } from '../../api'
import ImportedWarningBubble from '../imported-warning-bubble'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import {
  DimensionCellWithBar,
  DimensionCellWithBarProps,
  IndexBreakdown
} from '../reports/index-breakdown'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import { DashboardState } from '../../dashboard-state'
import { BrowserIcon, OsIcon, ScreenSizeIcon } from './icons'
import { FilterInfo } from '../../components/drilldown-link'

type SelectedTab =
  | BreakdownReportKey.browsers
  | BreakdownReportKey.operatingSystems
  | BreakdownReportKey.screenSizes

type SelectedReport =
  | SelectedTab
  | BreakdownReportKey.browserVersions
  | BreakdownReportKey.operatingSystemVersions

const initMode = (storedMode: string): SelectedTab => {
  switch (storedMode) {
    case 'os':
    case BreakdownReportKey.operatingSystems:
      return BreakdownReportKey.operatingSystems
    case 'size':
    case BreakdownReportKey.screenSizes:
      return BreakdownReportKey.screenSizes
    case 'browser':
    case BreakdownReportKey.browsers:
    default:
      return BreakdownReportKey.browsers
  }
}

const BAR_COLOR = 'bg-green-50 group-hover/row:bg-green-100'

function getSelectedReport(
  mode: SelectedTab,
  dashboardState: DashboardState
): SelectedReport {
  switch (mode) {
    case BreakdownReportKey.browsers:
      return isFilteringOnFixedValue(dashboardState, 'browser')
        ? BreakdownReportKey.browserVersions
        : BreakdownReportKey.browsers
    case BreakdownReportKey.operatingSystems:
      return isFilteringOnFixedValue(dashboardState, 'os')
        ? BreakdownReportKey.operatingSystemVersions
        : BreakdownReportKey.operatingSystems
    case BreakdownReportKey.screenSizes:
      return BreakdownReportKey.screenSizes
  }
}

export function Devices() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const tabKey = `deviceTab__${site.domain}`
  const [mode, setMode] = useState<SelectedTab>(
    initMode(storage.getItem(tabKey))
  )
  const [currentData, setCurrentData] = useState<QueryApiResponse | null>(null)

  const selectedReportKey = getSelectedReport(mode, dashboardState)
  const reportConfig = BREAKDOWN_REPORTS[selectedReportKey]
  const DimensionElement = {
    [BreakdownReportKey.browsers]: BrowsersDimensionCell,
    [BreakdownReportKey.browserVersions]: BrowserVersionsDimensionCell,
    [BreakdownReportKey.operatingSystems]: OperatingSystemsDimensionCell,
    [BreakdownReportKey.operatingSystemVersions]:
      OperatingSystemVersionsDimensionCell,
    [BreakdownReportKey.screenSizes]: ScreenSizesDimensionCell
  }[selectedReportKey]

  const metrics = chooseBreakdownMetricsByContext(
    reportConfig.metricsByContext,
    {
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: false,
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRevenueAvailable: false
    }
  )

  function switchTab(mode: SelectedTab) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  const moreLinkState = currentData
    ? currentData.results.length > 0
      ? MoreLinkState.READY
      : MoreLinkState.HIDDEN
    : MoreLinkState.LOADING

  return (
    <ReportLayout testId="report-devices" className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {(
              [
                { label: 'Browsers', value: BreakdownReportKey.browsers },
                {
                  label: 'Operating systems',
                  value: BreakdownReportKey.operatingSystems
                },
                { label: 'Devices', value: BreakdownReportKey.screenSizes }
              ] as const
            ).map(({ label, value }) => (
              <TabButton
                key={value}
                active={mode === value}
                onClick={() => switchTab(value)}
              >
                {label}
              </TabButton>
            ))}
          </TabWrapper>
          <ImportedWarningBubble queryApiResponse={currentData} />
        </div>
        <MoreLink
          state={moreLinkState}
          linkProps={{
            path: reportConfig.detailsPath,
            search: (search: string) => search
          }}
        />
      </ReportHeader>
      <IndexBreakdown
        metrics={metrics}
        dimensions={reportConfig.dimensions}
        dimensionLabel={reportConfig.dimensionLabel}
        DimensionElement={DimensionElement}
        onDataReady={setCurrentData}
        getFilterInfo={
          selectedReportKey === BreakdownReportKey.screenSizes
            ? getScreenFilterInfo
            : undefined
        }
      />
    </ReportLayout>
  )
}

const BrowsersDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    text={props.row.dimensions[0]}
    icon={<BrowserIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const BrowserVersionsDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    text={formatTwoDimensionsText(props.row)}
    icon={<BrowserIcon dimensionValue={props.row.dimensions[1]} />}
  />
)

const OperatingSystemsDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    text={props.row.dimensions[0]}
    icon={<OsIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const OperatingSystemVersionsDimensionCell = (
  props: DimensionCellWithBarProps
) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    text={formatTwoDimensionsText(props.row)}
    icon={<OsIcon dimensionValue={props.row.dimensions[1]} />}
  />
)

const ScreenSizesDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    text={props.row.dimensions[0]}
    icon={<ScreenSizeIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const formatTwoDimensionsText = (row: QueryResultRow) =>
  row.dimensions[0] === '(not set)' && row.dimensions[1] === '(not set)'
    ? '(not set)'
    : `${row.dimensions[1]} ${row.dimensions[0]}`

export const getScreenFilterInfo = (
  _dimension: string,
  row: QueryResultRow
): FilterInfo => ({
  filter: ['is', 'screen', [row.dimensions[0]]],
  prefix: 'screen'
})
