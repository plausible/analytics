import React, { useCallback, useEffect, useRef, useState } from 'react'

import * as storage from '../../util/storage'
import CountriesMap from './map'

import {
  hasConversionGoalFilter,
  isRealTimeDashboard,
  getFiltersByKeyPrefix
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
import { FilterInfo } from '../../components/drilldown-link'
import { NonTimeDimension } from '../../stats-query'
import { FlagEmoji } from './flag-emoji'
import { DashboardState } from '../../dashboard-state'

type MapTabKey = 'map'
type TabKey =
  | MapTabKey
  | BreakdownReportKey.countries
  | BreakdownReportKey.regions
  | BreakdownReportKey.cities

export type LocationsReportKey =
  | BreakdownReportKey.countries
  | BreakdownReportKey.regions
  | BreakdownReportKey.cities

const BAR_COLOR = 'bg-orange-50 group-hover/row:bg-orange-100'

const initTab = (storedTab: string | null): TabKey => {
  switch (storedTab) {
    case BreakdownReportKey.countries:
      return BreakdownReportKey.countries
    case BreakdownReportKey.regions:
      return BreakdownReportKey.regions
    case BreakdownReportKey.cities:
      return BreakdownReportKey.cities
    case 'map':
    default:
      return 'map'
  }
}

const getAppliedLocationsFilters = (dashboardState: DashboardState) => ({
  countryFiltersApplied:
    getFiltersByKeyPrefix(dashboardState, 'country').length > 0,
  regionFiltersApplied:
    getFiltersByKeyPrefix(dashboardState, 'region').length > 0
})

export function Locations() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const tabKey = `geoTab__${site.domain}`
  const [tab, setTab] = useState<TabKey>(initTab(storage.getItem(tabKey)))
  // determines whether to show list or map (the default) when zooming out of Regions tab
  const [prefersCountriesList, setPrefersCountriesList] =
    useState<boolean>(false)
  const [currentData, setCurrentData] = useState<QueryApiResponse | null>(null)

  useEffect(() => {
    storage.setItem(tabKey, tab)
  }, [tabKey, tab])

  const prevFilters = useRef<{
    countryFiltersApplied: boolean
    regionFiltersApplied: boolean
  }>(getAppliedLocationsFilters(dashboardState))

  /**
   * Clicking on a country applies "Country is ..." filter and zooms to Regions tab,
   * clicking on a region applies "Region is ..." filter and zooms to Cities tab (see onClick handlers below).
   * This effect handles zooming out of Regions tab on dismissing the countries filter,
   * and zooming out of Cities tab on dismissing the regions filter.
   */
  useEffect(() => {
    setTab((currentTab) => {
      const { countryFiltersApplied, regionFiltersApplied } =
        getAppliedLocationsFilters(dashboardState)
      const prev = { ...prevFilters.current }
      prevFilters.current = { countryFiltersApplied, regionFiltersApplied }

      if (
        currentTab === BreakdownReportKey.regions &&
        prev.countryFiltersApplied &&
        !countryFiltersApplied
      ) {
        return prefersCountriesList ? BreakdownReportKey.countries : 'map'
      }

      if (
        currentTab === BreakdownReportKey.cities &&
        prev.regionFiltersApplied &&
        !regionFiltersApplied
      ) {
        return BreakdownReportKey.regions
      }

      return currentTab
    })
  }, [prefersCountriesList, dashboardState])

  const selectedListKey: LocationsReportKey =
    tab === 'map' ? BreakdownReportKey.countries : tab
  const reportConfig = BREAKDOWN_REPORTS[selectedListKey]

  const metrics = reportConfig.getMetrics({
    isRealtime: isRealTimeDashboard(dashboardState),
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })

  const moreLinkState = currentData
    ? currentData.results.length > 0
      ? MoreLinkState.READY
      : MoreLinkState.HIDDEN
    : MoreLinkState.LOADING

  const moreLinkPath = reportConfig.detailsPath

  const CountriesDimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => (
      <CountriesDimensionCell
        {...props}
        onClick={() => {
          setPrefersCountriesList(true)
          setTab(BreakdownReportKey.regions)
        }}
      />
    ),
    []
  )

  const RegionsDimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => (
      <RegionsDimensionCell
        {...props}
        onClick={() => setTab(BreakdownReportKey.cities)}
      />
    ),
    []
  )

  const DimensionElement = {
    [BreakdownReportKey.countries]: CountriesDimensionElement,
    [BreakdownReportKey.regions]: RegionsDimensionElement,
    [BreakdownReportKey.cities]: CitiesDimensionCell
  }[selectedListKey]

  return (
    <ReportLayout
      testId="report-locations"
      className={tab === 'map' ? '' : 'overflow-x-hidden'}
    >
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {(
              [
                { label: 'Map', value: 'map' },
                {
                  label: 'Countries',
                  value: BreakdownReportKey.countries
                },
                { label: 'Regions', value: BreakdownReportKey.regions },
                { label: 'Cities', value: BreakdownReportKey.cities }
              ] as const
            ).map(({ label, value }) => (
              <TabButton
                key={value}
                active={tab === value}
                onClick={() => setTab(value)}
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
            path: moreLinkPath,
            search: (search: string) => search
          }}
        />
      </ReportHeader>
      {tab === 'map' ? (
        <CountriesMap
          onCountrySelect={() => {
            setPrefersCountriesList(false)
            setTab(BreakdownReportKey.regions)
          }}
          onDataReady={setCurrentData}
        />
      ) : (
        <IndexBreakdown
          metrics={metrics}
          dimensions={reportConfig.dimensions}
          dimensionLabel={reportConfig.dimensionLabel}
          alwaysOnFilters={reportConfig.alwaysOnFilters}
          DimensionElement={DimensionElement}
          onDataReady={setCurrentData}
        />
      )}
    </ReportLayout>
  )
}

const CountriesDimensionCell = (
  props: DimensionCellWithBarProps & { onClick: () => void }
) => {
  const [countryName, countryCode] = props.row.dimensions
  return (
    <DimensionCellWithBar
      {...props}
      barClassName={BAR_COLOR}
      text={countryName}
      icon={<FlagEmoji countryCode={countryCode} />}
      getFilterInfo={getCountriesFilterInfo}
    />
  )
}

const RegionsDimensionCell = (
  props: DimensionCellWithBarProps & { onClick: () => void }
) => {
  const [regionName, _regionCode, countryCode] = props.row.dimensions
  return (
    <DimensionCellWithBar
      {...props}
      barClassName={BAR_COLOR}
      text={regionName}
      icon={<FlagEmoji countryCode={countryCode} />}
      getFilterInfo={getRegionsFilterInfo}
    />
  )
}

const CitiesDimensionCell = (props: DimensionCellWithBarProps) => {
  const [cityName, _cityCode, countryCode] = props.row.dimensions
  return (
    <DimensionCellWithBar
      {...props}
      barClassName={BAR_COLOR}
      text={cityName}
      icon={<FlagEmoji countryCode={countryCode} />}
      getFilterInfo={getCitiesFilterInfo}
    />
  )
}

export const getCountriesFilterInfo = (
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo => {
  const [countryName, countryCode] = row.dimensions

  return {
    prefix: 'country',
    filter: ['is', 'country', [countryCode]],
    labels: { [countryCode]: countryName }
  }
}

export const getRegionsFilterInfo = (
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo => {
  const [regionName, regionCode, _countryCode] = row.dimensions

  return {
    prefix: 'region',
    filter: ['is', 'region', [regionCode]],
    labels: { [regionCode]: regionName }
  }
}

export const getCitiesFilterInfo = (
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo => {
  const [cityName, cityCode, _countryCode] = row.dimensions

  return {
    prefix: 'city',
    filter: ['is', 'city', [cityCode]],
    labels: { [cityCode]: cityName }
  }
}

export default Locations
