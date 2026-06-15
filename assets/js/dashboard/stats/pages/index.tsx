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
  BreakdownReportKey
} from '../reports/reports-config'
import {
  DimensionCellWithBar,
  IndexBreakdown,
  DimensionCellWithBarProps
} from '../reports/index-breakdown'
import { defaultGetFilterInfo } from '../breakdowns'
import { externalLinkForPage, trimURL } from '../../util/url'
import { IndexExternalLink } from './external-link'

const BAR_COLOR = 'bg-orange-50 group-hover/row:bg-orange-100'
const MAX_DIMENSION_LENGTH = 70

export default function Pages() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const storageKey = `pageTab__${site.domain}`
  const [tab, setTab] = useState<TabKey>(initTab(storage.getItem(storageKey)))
  const [currentData, setCurrentData] = useState<QueryApiResponse | null>(null)

  const reportKey = getReportKey(tab)
  const reportConfig = BREAKDOWN_REPORTS[reportKey]

  const metrics = reportConfig.getMetrics({
    isRealtime: isRealTimeDashboard(dashboardState),
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })

  function switchTab(tab: TabKey) {
    storage.setItem(storageKey, tab)
    setTab(tab)
  }

  function moreLinkProps() {
    return {
      path: reportConfig.detailsPath,
      search: (search: string) => search
    }
  }

  function renderContent() {
    return (
      <IndexBreakdown
        metrics={metrics}
        dimensions={reportConfig.dimensions}
        dimensionLabel={reportConfig.dimensionLabel}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        DimensionElement={PagesDimensionCell}
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
                active={tab === value}
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

function PagesDimensionCell(props: DimensionCellWithBarProps) {
  const site = useSiteContext()
  const externalUrl = externalLinkForPage(site, props.row.dimensions[0])
  const displayValue = trimURL(props.row.dimensions[0], MAX_DIMENSION_LENGTH)
  return (
    <DimensionCellWithBar
      getFilterInfo={defaultGetFilterInfo}
      text={displayValue}
      barClassName={BAR_COLOR}
      externalLink={
        externalUrl && (
          <IndexExternalLink href={externalUrl} isActive={props.isActive} />
        )
      }
      {...props}
    />
  )
}

const initTab = (storedTab: string): TabKey => {
  switch (storedTab) {
    case LegacyTabKey.entryPages:
    case BreakdownReportKey.entryPages:
      return BreakdownReportKey.entryPages
    case LegacyTabKey.exitPages:
    case BreakdownReportKey.exitPages:
      return BreakdownReportKey.exitPages
    case BreakdownReportKey.pages:
    default:
      return BreakdownReportKey.pages
  }
}

const getReportKey = (tab: TabKey): ReportKey => tab

type TabKey =
  | BreakdownReportKey.pages
  | BreakdownReportKey.entryPages
  | BreakdownReportKey.exitPages

type ReportKey = TabKey

enum LegacyTabKey {
  entryPages = 'entry-pages',
  exitPages = 'exit-pages'
}
