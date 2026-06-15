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
import { defaultGetFilterInfo, getScreenFilterInfo } from '../breakdowns'
import { DashboardState } from '../../dashboard-state'
import { BrowserIcon, OsIcon, ScreenSizeIcon } from './icons'

const BAR_COLOR = 'bg-green-50 group-hover/row:bg-green-100'

export function Devices() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const storageKey = `deviceTab__${site.domain}`
  const [tab, setTab] = useState<TabKey>(initTab(storage.getItem(storageKey)))
  const [currentData, setCurrentData] = useState<QueryApiResponse | null>(null)

  const reportKey = getReportKey(tab, dashboardState)
  const reportConfig = BREAKDOWN_REPORTS[reportKey]
  const DimensionElement = {
    [BreakdownReportKey.browsers]: BrowsersDimensionCell,
    [BreakdownReportKey.browserVersions]: BrowserVersionsDimensionCell,
    [BreakdownReportKey.operatingSystems]: OperatingSystemsDimensionCell,
    [BreakdownReportKey.operatingSystemVersions]:
      OperatingSystemVersionsDimensionCell,
    [BreakdownReportKey.screenSizes]: ScreenSizesDimensionCell
  }[reportKey]

  const metrics = reportConfig.getMetrics({
    isRealtime: isRealTimeDashboard(dashboardState),
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })

  function switchTab(tab: TabKey) {
    storage.setItem(storageKey, tab)
    setTab(tab)
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
                active={tab === value}
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
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        DimensionElement={DimensionElement}
        onDataReady={setCurrentData}
      />
    </ReportLayout>
  )
}

const BrowsersDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    getFilterInfo={defaultGetFilterInfo}
    text={props.row.dimensions[0]}
    icon={<BrowserIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const BrowserVersionsDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    getFilterInfo={defaultGetFilterInfo}
    text={formatTwoDimensionsText(props.row)}
    icon={<BrowserIcon dimensionValue={props.row.dimensions[1]} />}
  />
)

const OperatingSystemsDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    getFilterInfo={defaultGetFilterInfo}
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
    getFilterInfo={defaultGetFilterInfo}
    text={formatTwoDimensionsText(props.row)}
    icon={<OsIcon dimensionValue={props.row.dimensions[1]} />}
  />
)

const ScreenSizesDimensionCell = (props: DimensionCellWithBarProps) => (
  <DimensionCellWithBar
    {...props}
    barClassName={BAR_COLOR}
    getFilterInfo={getScreenFilterInfo}
    text={props.row.dimensions[0]}
    icon={<ScreenSizeIcon dimensionValue={props.row.dimensions[0]} />}
  />
)

const formatTwoDimensionsText = (row: QueryResultRow) =>
  row.dimensions[0] === '(not set)' && row.dimensions[1] === '(not set)'
    ? '(not set)'
    : `${row.dimensions[1]} ${row.dimensions[0]}`

function getReportKey(tab: TabKey, dashboardState: DashboardState): ReportKey {
  switch (tab) {
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

type TabKey =
  | BreakdownReportKey.browsers
  | BreakdownReportKey.operatingSystems
  | BreakdownReportKey.screenSizes

type ReportKey =
  | TabKey
  | BreakdownReportKey.browserVersions
  | BreakdownReportKey.operatingSystemVersions

const initTab = (storedTab: string): TabKey => {
  switch (storedTab) {
    case LegacyTabKey.operatingSystems:
    case BreakdownReportKey.operatingSystems:
      return BreakdownReportKey.operatingSystems
    case LegacyTabKey.screenSizes:
    case BreakdownReportKey.screenSizes:
      return BreakdownReportKey.screenSizes
    case LegacyTabKey.browsers:
    case BreakdownReportKey.browsers:
    default:
      return BreakdownReportKey.browsers
  }
}

enum LegacyTabKey {
  browsers = 'browser',
  operatingSystems = 'os',
  screenSizes = 'size'
}
