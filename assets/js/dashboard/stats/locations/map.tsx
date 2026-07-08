import React, { useCallback, useEffect, useMemo, useState } from 'react'
import {
  replaceFilterByPrefix,
  cleanLabels,
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { MIN_HEIGHT } from '../reports/index-breakdown'
import { GeolocationNotice } from './geolocation-notice'
import { DashboardState } from '../../dashboard-state'
import { useQueryApi } from '../../hooks/use-query-api'
import { QueryApiResponse } from '../../api'
import { COUNTRIES_BY_TWO_LETTER_CODE } from './countries'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import LazyLoader from '../../components/lazy-loader'
import { CountryData, MetricLabel, WorldMapSvg } from './world-map-svg'

function getMetricLabel(dashboardState: DashboardState): MetricLabel {
  if (hasConversionGoalFilter(dashboardState)) {
    return { singular: 'Conversion', plural: 'Conversions' }
  }
  if (isRealTimeDashboard(dashboardState)) {
    return { singular: 'Current visitor', plural: 'Current visitors' }
  }
  return { singular: 'Visitor', plural: 'Visitors' }
}

const WorldMap = ({
  onCountrySelect,
  onDataReady
}: {
  onCountrySelect: () => void
  onDataReady: (response: QueryApiResponse) => void
}) => {
  const navigate = useAppNavigate()
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [visible, setVisible] = useState(false)

  const metricLabel = useMemo(
    () => getMetricLabel(dashboardState),
    [dashboardState]
  )

  const { apiState, isRealtimeSilentUpdate } = useQueryApi(
    site,
    [
      'visit:country',
      {
        dashboardState,
        reportParams: {
          metrics: ['visitors'],
          dimensions:
            BREAKDOWN_REPORTS[BreakdownReportKey.countries].dimensions,
          alwaysOnFilters:
            BREAKDOWN_REPORTS[BreakdownReportKey.countries].alwaysOnFilters,
          order_by: [['visitors', 'desc']],
          pagination: { limit: 300, offset: 0 }
        }
      }
    ],
    { enabled: visible }
  )
  const { data, isPending, isPlaceholderData, isError } = apiState

  const isLoading =
    isPending || isError || (isPlaceholderData && !isRealtimeSilentUpdate)

  useEffect(() => {
    if (data) {
      onDataReady(data)
    }
  }, [onDataReady, data])

  const { maxValue, dataByAlpha3Code } = useMemo(() => {
    const dataByAlpha3Code: Map<string, CountryData> = new Map()
    let maxValue = 0
    for (const row of data?.results ?? []) {
      const [countryName, countryCode] = row.dimensions
      const [visitors] = row.metrics as [number]
      const entry = COUNTRIES_BY_TWO_LETTER_CODE[countryCode]
      if (!entry || !entry.alpha_3) continue
      if (visitors > maxValue) {
        maxValue = visitors
      }
      dataByAlpha3Code.set(entry.alpha_3, {
        alpha_3: entry.alpha_3,
        visitors,
        name: countryName,
        code: countryCode
      })
    }
    return { maxValue, dataByAlpha3Code }
  }, [data])

  const onCountryClick = useCallback(
    (country: CountryData) => {
      const filters = replaceFilterByPrefix(dashboardState, 'country', [
        'is',
        'country',
        [country.code]
      ])
      const labels = cleanLabels(filters, dashboardState.labels, 'country', {
        [country.code]: country.name
      })
      onCountrySelect()
      navigate({
        search: (searchRecord) => ({ ...searchRecord, filters, labels })
      })
    },
    [navigate, dashboardState, onCountrySelect]
  )

  return (
    <LazyLoader onVisible={() => setVisible(true)}>
      <div
        className="flex flex-col justify-center items-center relative"
        style={{ minHeight: MIN_HEIGHT }}
      >
        {isLoading ? (
          <div className="mx-auto loading">
            <div />
          </div>
        ) : (
          <WorldMapSvg
            maxValue={maxValue}
            dataByAlpha3Code={dataByAlpha3Code}
            metricLabel={metricLabel}
            onCountryClick={onCountryClick}
          />
        )}
        {site.isDbip && <GeolocationNotice />}
      </div>
    </LazyLoader>
  )
}

export default WorldMap
