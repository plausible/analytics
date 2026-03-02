import React, { createContext, useMemo, useContext, ReactNode } from 'react'
import { useLocation } from 'react-router'
import { useMountedEffect } from './custom-hooks'
import * as api from './api'
import { useSiteContext } from './site-context'
import { parseSearch } from './util/url-search-params'
import dayjs from 'dayjs'
import { nowForSite, yesterday } from './util/date'
import {
  getDashboardTimeSettings,
  getSavedTimePreferencesFromStorage,
  DashboardPeriod,
  useSaveTimePreferencesToStorage
} from './dashboard-time-periods'
import {
  Filter,
  FilterClauseLabels,
  dashboardStateDefaultValue,
  postProcessFilters
} from './dashboard-state'
import { resolveFilters, SavedSegment, SegmentData } from './filtering/segments'
import { useDefiniteLocationState } from './navigation/use-definite-location-state'
import { useClearExpandedSegmentModeOnFilterClear } from './nav-menu/segments/segment-menu'
import { useSegmentsContext } from './filtering/segments-context'

const dashboardStateContextDefaultValue = {
  dashboardState: dashboardStateDefaultValue,
  otherSearch: {} as Record<string, unknown>,
  expandedSegment: null as (SavedSegment & { segment_data: SegmentData }) | null
}

export type DashboardStateContextValue =
  typeof dashboardStateContextDefaultValue

const DashboardStateContext = createContext(dashboardStateContextDefaultValue)

export const useDashboardStateContext = () => {
  return useContext(DashboardStateContext)
}

export default function DashboardStateContextProvider({
  children
}: {
  children: ReactNode
}) {
  const segmentsContext = useSegmentsContext()
  const location = useLocation()
  const { definiteValue: expandedSegment } = useDefiniteLocationState<
    SavedSegment & { segment_data: SegmentData }
  >('expandedSegment')
  const site = useSiteContext()

  const {
    compare_from,
    compare_to,
    comparison,
    date,
    filters: rawFilters,
    from,
    labels,
    match_day_of_week,
    period,
    to,
    with_imported,
    ...otherSearch
  } = useMemo(() => parseSearch(location.search), [location.search])

  const dashboardState = useMemo(() => {
    const defaultValues = dashboardStateDefaultValue
    const storedValues = getSavedTimePreferencesFromStorage({ site })
    const timeSettings = getDashboardTimeSettings({
      site,
      searchValues: { period, comparison, match_day_of_week },
      storedValues,
      defaultValues,
      segmentIsExpanded: !!expandedSegment
    })

    const filters = Array.isArray(rawFilters)
      ? postProcessFilters(rawFilters as Filter[])
      : defaultValues.filters

    const resolvedFilters = resolveFilters(filters, segmentsContext.segments)

    return {
      ...timeSettings,
      compare_from:
        typeof compare_from === 'string' && compare_from.length
          ? dayjs.utc(compare_from)
          : defaultValues.compare_from,
      compare_to:
        typeof compare_to === 'string' && compare_to.length
          ? dayjs.utc(compare_to)
          : defaultValues.compare_to,
      date:
        typeof date === 'string' && date.length
          ? dayjs.utc(date)
          : nowForSite(site),
      from:
        typeof from === 'string' && from.length
          ? dayjs.utc(from)
          : timeSettings.period === DashboardPeriod.custom
            ? yesterday(site)
            : defaultValues.from,
      to:
        typeof to === 'string' && to.length
          ? dayjs.utc(to)
          : timeSettings.period === DashboardPeriod.custom
            ? nowForSite(site)
            : defaultValues.to,
      with_imported: [true, false].includes(with_imported as boolean)
        ? (with_imported as boolean)
        : defaultValues.with_imported,
      filters,
      resolvedFilters,
      labels: (labels as FilterClauseLabels) || defaultValues.labels
    }
  }, [
    compare_from,
    compare_to,
    comparison,
    date,
    rawFilters,
    from,
    labels,
    match_day_of_week,
    period,
    to,
    with_imported,
    site,
    expandedSegment,
    segmentsContext.segments
  ])

  useClearExpandedSegmentModeOnFilterClear({ expandedSegment, dashboardState })
  useSaveTimePreferencesToStorage({
    site,
    period,
    comparison,
    match_day_of_week
  })

  useMountedEffect(() => {
    api.cancelAll()
  }, [])

  return (
    <DashboardStateContext.Provider
      value={{
        dashboardState,
        otherSearch,
        expandedSegment
      }}
    >
      {children}
    </DashboardStateContext.Provider>
  )
}
