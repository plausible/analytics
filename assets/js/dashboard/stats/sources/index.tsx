import React, { useCallback, useEffect, useState } from 'react'

import * as storage from '../../util/storage'
import * as url from '../../util/url'
import * as api from '../../api'
import usePrevious from '../../hooks/use-previous'
import {
  getFiltersByKeyPrefix,
  hasConversionGoalFilter,
  isFilteringOnFixedValue,
  isRealTimeDashboard
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { SourceFavicon } from './source-favicon'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { DropdownTabButton, TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'
import { DashboardState } from '../../dashboard-state'
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
import ImportedWarningBubble from '../imported-warning-bubble'
import { IndexExternalLink } from '../pages/external-link'
import { FilterInfo } from '../../components/drilldown-link'

const BAR_COLOR = 'bg-blue-50 group-hover/row:bg-blue-100'
const MAX_DIMENSION_LENGTH = 70
const SEARCH_TERMS_KEY = 'searchTerms'
const DIRECT_NONE = 'Direct / None'

const UTM_TAB_KEYS = [
  BreakdownReportKey.utmMediums,
  BreakdownReportKey.utmSources,
  BreakdownReportKey.utmCampaigns,
  BreakdownReportKey.utmContents,
  BreakdownReportKey.utmTerms
] as const

type TabKey =
  | BreakdownReportKey.channels
  | BreakdownReportKey.sources
  | (typeof UTM_TAB_KEYS)[number]

type ReportKey = TabKey | BreakdownReportKey.referrers | typeof SEARCH_TERMS_KEY

const isGoogleSourceFilter = (dashboardState: DashboardState) => {
  return isFilteringOnFixedValue(dashboardState, 'source', 'Google')
}

const isFixedSourceFilter = (dashboardState: DashboardState) => {
  return isFilteringOnFixedValue(dashboardState, 'source')
}

const getFixedSourceFilterClause = (dashboardState: DashboardState) => {
  if (isFixedSourceFilter(dashboardState)) {
    const [[_operation, _filterKey, clauses]] = getFiltersByKeyPrefix(
      dashboardState,
      'source'
    )

    return clauses[0]
  }
  return null
}

const getCurrentReportKey = (
  currentTab: TabKey,
  dashboardState: DashboardState
): ReportKey => {
  if (
    currentTab === BreakdownReportKey.sources &&
    isGoogleSourceFilter(dashboardState)
  ) {
    return SEARCH_TERMS_KEY
  }
  if (
    currentTab === BreakdownReportKey.sources &&
    isFixedSourceFilter(dashboardState)
  ) {
    return BreakdownReportKey.referrers
  }
  return currentTab
}

function initTab(storedMode: string): TabKey {
  if (['channels', BreakdownReportKey.channels].includes(storedMode)) {
    return BreakdownReportKey.channels
  }
  if (['utm_mediums', BreakdownReportKey.utmMediums].includes(storedMode)) {
    return BreakdownReportKey.utmMediums
  }
  if (['utm_sources', BreakdownReportKey.utmSources].includes(storedMode)) {
    return BreakdownReportKey.utmSources
  }
  if (['utm_campaigns', BreakdownReportKey.utmCampaigns].includes(storedMode)) {
    return BreakdownReportKey.utmCampaigns
  }
  if (['utm_contents', BreakdownReportKey.utmContents].includes(storedMode)) {
    return BreakdownReportKey.utmContents
  }
  if (['utm_terms', BreakdownReportKey.utmTerms].includes(storedMode)) {
    return BreakdownReportKey.utmTerms
  }
  return BreakdownReportKey.sources
}

function isUtmTab(tabKey: TabKey) {
  return (UTM_TAB_KEYS as ReadonlyArray<TabKey>).includes(tabKey)
}

export default function Sources() {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const tabStorageKey = 'sourceTab__' + site.domain
  const [currentTab, setTab] = useState<TabKey>(
    initTab(storage.getItem(tabStorageKey))
  )
  const [currentData, setCurrentData] = useState<api.QueryApiResponse | null>(
    null
  )
  const previousDashboardState = usePrevious(dashboardState)

  const currentReportKey = getCurrentReportKey(currentTab, dashboardState)

  const setAndStoreTab = useCallback(
    (tab: TabKey) => {
      storage.setItem(tabStorageKey, tab)
      setTab(tab)
    },
    [tabStorageKey]
  )

  function moreLinkProps() {
    if (currentReportKey === SEARCH_TERMS_KEY) {
      return {
        path: 'google-search-terms',
        search: (search: string) => search
      }
    }
    if (currentReportKey === BreakdownReportKey.referrers) {
      return {
        path: BREAKDOWN_REPORTS[currentReportKey].detailsPath,
        params: {
          referrer: url.maybeEncodeRouteParam(
            getFixedSourceFilterClause(dashboardState)
          )
        },
        search: (search: string) => search
      }
    }
    return {
      path: BREAKDOWN_REPORTS[currentReportKey].detailsPath,
      search: (search: string) => search
    }
  }

  const ChannelsDimensionCell = useCallback(
    (props: DimensionCellWithBarProps) => (
      <DimensionCellWithBar
        text={url.trimURL(props.row.dimensions[0], MAX_DIMENSION_LENGTH)}
        onClick={() => setAndStoreTab(BreakdownReportKey.sources)}
        barClassName={BAR_COLOR}
        {...props}
      />
    ),
    [setAndStoreTab]
  )

  function renderContent() {
    if (currentReportKey === SEARCH_TERMS_KEY) {
      // Todo
      // return (<SearchTerms
      //   loading={loading}
      //   afterFetchData={afterFetchData as (res: object | null) => void}
      //   onLoadStart={onLoadStart}
      // />)
      return null
    }

    const reportConfig = BREAKDOWN_REPORTS[currentReportKey]

    const metrics = chooseBreakdownMetricsByContext(
      reportConfig.metricsByContext,
      {
        isRealtime: isRealTimeDashboard(dashboardState),
        isDetailed: false,
        hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
        isRevenueAvailable: false
      }
    )

    const DimensionElement = {
      [BreakdownReportKey.channels]: ChannelsDimensionCell,
      [BreakdownReportKey.sources]: SourcesDimensionCell,
      [BreakdownReportKey.referrers]: ReferrerUrlDimensionCell,
      [BreakdownReportKey.utmMediums]: UtmDimensionCell,
      [BreakdownReportKey.utmSources]: UtmDimensionCell,
      [BreakdownReportKey.utmCampaigns]: UtmDimensionCell,
      [BreakdownReportKey.utmContents]: UtmDimensionCell,
      [BreakdownReportKey.utmTerms]: UtmDimensionCell
    }[currentReportKey]

    return (
      <IndexBreakdown
        metrics={metrics}
        dimensions={reportConfig.dimensions}
        dimensionLabel={reportConfig.dimensionLabel}
        DimensionElement={DimensionElement}
        onDataReady={setCurrentData}
        // Possible improvement: getFilterInfo can be dropped from IndexBreakdown props
        // and be given directly to DimensionCell element (which would also provide the
        // default function)
        getFilterInfo={
          currentReportKey === BreakdownReportKey.referrers
            ? getReferrerUrlFilterInfo
            : undefined
        }
      />
    )
  }

  const moreLinkState = currentData
    ? currentData.results.length > 0
      ? MoreLinkState.READY
      : MoreLinkState.HIDDEN
    : MoreLinkState.LOADING

  useEffect(() => {
    const isRemovingFilter = (filterName: string) => {
      if (!previousDashboardState) return false

      return (
        getFiltersByKeyPrefix(previousDashboardState, filterName).length > 0 &&
        getFiltersByKeyPrefix(dashboardState, filterName).length == 0
      )
    }

    if (
      currentTab == BreakdownReportKey.sources &&
      isRemovingFilter('channel')
    ) {
      setAndStoreTab(BreakdownReportKey.channels)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboardState, currentTab])

  function sourceTabLabel() {
    if (isGoogleSourceFilter(dashboardState)) {
      return 'Search terms'
    } else if (isFixedSourceFilter(dashboardState)) {
      return 'Top referrers'
    } else {
      return 'Sources'
    }
  }

  return (
    <ReportLayout testId="report-sources" className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {[
              { value: BreakdownReportKey.channels, label: 'Channels' },
              { value: BreakdownReportKey.sources, label: sourceTabLabel() }
            ].map(({ value, label }) => (
              <TabButton
                key={value}
                onClick={() => setAndStoreTab(value as TabKey)}
                active={currentTab === value}
              >
                {label}
              </TabButton>
            ))}
            <DropdownTabButton
              className="md:relative"
              transitionClassName="md:left-auto md:w-56 md:origin-top-right"
              active={isUtmTab(currentTab)}
              options={UTM_TAB_KEYS.map((utmTabKey) => ({
                label: BREAKDOWN_REPORTS[utmTabKey].detailsTitle,
                onClick: () => setAndStoreTab(utmTabKey),
                selected: currentTab === utmTabKey
              }))}
            >
              {isUtmTab(currentTab)
                ? BREAKDOWN_REPORTS[currentTab].detailsTitle
                : 'Campaigns'}
            </DropdownTabButton>
          </TabWrapper>
          <ImportedWarningBubble queryApiResponse={currentData} />
        </div>
        <MoreLink state={moreLinkState} linkProps={moreLinkProps()} />
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}

export const getReferrerUrlFilterInfo = (
  _dimension: string,
  row: api.QueryResultRow
): FilterInfo | null => {
  if (row.dimensions[0] === DIRECT_NONE) {
    return null
  }
  return {
    prefix: 'referrer',
    filter: ['is', 'referrer', [row.dimensions[0]]]
  }
}

function UtmDimensionCell(props: DimensionCellWithBarProps) {
  const displayValue = url.trimURL(
    props.row.dimensions[0],
    MAX_DIMENSION_LENGTH
  )
  return (
    <DimensionCellWithBar
      text={displayValue}
      barClassName={BAR_COLOR}
      {...props}
    />
  )
}

function SourcesDimensionCell(props: DimensionCellWithBarProps) {
  const displayValue = url.trimURL(
    props.row.dimensions[0],
    MAX_DIMENSION_LENGTH
  )

  return (
    <DimensionCellWithBar
      text={displayValue}
      icon={
        <SourceFavicon name={props.row.dimensions[0]} className="size-4 mr-2" />
      }
      barClassName={BAR_COLOR}
      {...props}
    />
  )
}

function ReferrerUrlDimensionCell(props: DimensionCellWithBarProps) {
  const dimensionValue = props.row.dimensions[0]
  const displayValue = url.trimURL(dimensionValue, MAX_DIMENSION_LENGTH)

  const externalUrl =
    dimensionValue === DIRECT_NONE ? null : `https://${dimensionValue}`

  return (
    <DimensionCellWithBar
      text={displayValue}
      icon={<SourceFavicon name={dimensionValue} className="size-4 mr-2" />}
      externalLink={
        externalUrl && (
          <IndexExternalLink href={externalUrl} isActive={props.isActive} />
        )
      }
      barClassName={BAR_COLOR}
      {...props}
    />
  )
}
