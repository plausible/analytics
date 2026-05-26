import React, { useState } from 'react'

import * as storage from '../../util/storage'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'
import { QueryApiResponse } from '../../api'
import ImportedWarningBubble from '../imported-warning-bubble'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey,
  getExternalLinkUrlForPage
} from '../reports/reports-config'
import {
  IndexBreakdown,
  IndexBreakdownDimensionCellProps
} from '../reports/index-breakdown'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import { trimURL } from '../../util/url'
import classNames from 'classnames'
import { DrilldownLink } from '../../components/drilldown-link'
import { IndexExternalLink } from './external-link'

type Mode = Extract<BreakdownReportKey, 'pages' | 'entryPages' | 'exitPages'>

const initMode = (storedMode: string): Mode => {
  if (['entry-pages', BreakdownReportKey.entryPages].includes(storedMode)) {
    return BreakdownReportKey.entryPages
  }
  if (['exit-pages', BreakdownReportKey.exitPages].includes(storedMode)) {
    return BreakdownReportKey.exitPages
  }
  return BreakdownReportKey.pages
}

const BAR_COLOR = 'bg-orange-50 group-hover/row:bg-orange-100'
const MAX_DIMENSION_LENGTH = 70

export default function Pages() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const tabKey = `pageTab__${site.domain}`
  const [mode, setMode] = useState<Mode>(initMode(storage.getItem(tabKey)))
  const [currentData, setCurrentData] = useState<QueryApiResponse | null>(null)

  const currentModeReportConfig = BREAKDOWN_REPORTS[mode]

  const currentModeMetrics = chooseBreakdownMetricsByContext(
    currentModeReportConfig.metricsByContext,
    {
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: false,
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRevenueAvailable: false
    }
  )

  function switchTab(mode: Mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  function moreLinkProps() {
    return {
      path: currentModeReportConfig.detailsPath,
      search: (search: string) => search
    }
  }

  function renderContent() {
    return (
      <IndexBreakdown
        metrics={currentModeMetrics}
        dimensions={currentModeReportConfig.dimensions}
        dimensionLabel={currentModeReportConfig.dimensionLabel}
        DimensionElement={DimensionCell}
        onDataReady={setCurrentData}
      />
    )
  }

  const moreLinkState = currentData
    ? currentData.results.length > 0
      ? MoreLinkState.READY
      : MoreLinkState.HIDDEN
    : MoreLinkState.LOADING

  return (
    <ReportLayout testId="report-pages" className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {(
              [
                {
                  label: hasConversionGoalFilter(dashboardState)
                    ? 'Conversion pages'
                    : 'Top pages',
                  value: BreakdownReportKey.pages
                },
                { label: 'Entry pages', value: BreakdownReportKey.entryPages },
                { label: 'Exit pages', value: BreakdownReportKey.exitPages }
              ] as const
            ).map(({ value, label }) => (
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
        <MoreLink state={moreLinkState} linkProps={moreLinkProps()} />
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}

function DimensionCell({
  row,
  barWidthPercent,
  getFilterInfo,
  isActive
}: IndexBreakdownDimensionCellProps) {
  const site = useSiteContext()
  const externalUrl = getExternalLinkUrlForPage(site, row)
  const displayValue = trimURL(row.dimensions[0], MAX_DIMENSION_LENGTH)
  return (
    <div className="w-full h-full relative">
      <div
        className={classNames(
          `absolute top-0 left-0 h-full rounded-sm dark:bg-gray-500/15 dark:group-hover/row:bg-gray-500/30`,
          BAR_COLOR
        )}
        style={{ width: `${barWidthPercent}%` }}
      />
      <div className="flex justify-start items-center gap-x-1.5 px-2 py-1.5 text-sm dark:text-gray-300 relative z-9 break-all w-full">
        <DrilldownLink
          filterInfo={getFilterInfo(row)}
          extraClass="max-w-max w-full flex items-center md:overflow-hidden"
        >
          <span className="w-full md:truncate">{displayValue}</span>
        </DrilldownLink>
        {externalUrl && (
          <IndexExternalLink href={externalUrl} isActive={isActive} />
        )}
      </div>
    </div>
  )
}
