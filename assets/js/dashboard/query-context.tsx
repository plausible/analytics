/* @format */
import React, {
  createContext,
  useMemo,
  useContext,
  ReactNode,
  useEffect
} from 'react'
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
  QueryPeriod,
  useSaveTimePreferencesToStorage
} from './query-time-periods'
import {
  Filter,
  FilterClauseLabels,
  queryDefaultValue,
  postProcessFilters
} from './query'
import { SavedSegment, SegmentData } from './filtering/segments'
import { useDefiniteLocationState } from './navigation/use-definite-location-state'
import { useClearExpandedSegmentModeOnFilterClear } from './nav-menu/segments/segment-menu'
import { useMetricsInfoContext } from './stats/reports/metrics-info-context'
import { getFiltersByKeyPrefix, hasConversionGoalFilter } from './util/filters'

const queryContextDefaultValue = {
  query: queryDefaultValue,
  otherSearch: {} as Record<string, unknown>,
  expandedSegment: null as (SavedSegment & { segment_data: SegmentData }) | null
}

export type QueryContextValue = typeof queryContextDefaultValue

const QueryContext = createContext(queryContextDefaultValue)

export const useQueryContext = () => {
  return useContext(QueryContext)
}

export default function QueryContextProvider({
  children
}: {
  children: ReactNode
}) {
  const location = useLocation()
  const { definiteValue: expandedSegment } = useDefiniteLocationState<
    SavedSegment & { segment_data: SegmentData }
  >('expandedSegment')
  const site = useSiteContext()
  const { setValue: setMetricsInfoValue } = useMetricsInfoContext()
  const {
    compare_from,
    compare_to,
    comparison,
    date,
    filters,
    from,
    labels,
    match_day_of_week,
    period,
    to,
    with_imported,
    ...otherSearch
  } = useMemo(() => parseSearch(location.search), [location.search])

  const query = useMemo(() => {
    const defaultValues = queryDefaultValue
    const storedValues = getSavedTimePreferencesFromStorage({ site })
    const timeQuery = getDashboardTimeSettings({
      searchValues: { period, comparison, match_day_of_week },
      storedValues,
      defaultValues,
      segmentIsExpanded: !!expandedSegment
    })

    return {
      ...timeQuery,
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
          : timeQuery.period === QueryPeriod.custom
            ? yesterday(site)
            : defaultValues.from,
      to:
        typeof to === 'string' && to.length
          ? dayjs.utc(to)
          : timeQuery.period === QueryPeriod.custom
            ? nowForSite(site)
            : defaultValues.to,
      with_imported: [true, false].includes(with_imported as boolean)
        ? (with_imported as boolean)
        : defaultValues.with_imported,
      filters: Array.isArray(filters)
        ? postProcessFilters(filters as Filter[])
        : defaultValues.filters,
      labels: (labels as FilterClauseLabels) || defaultValues.labels
    }
  }, [
    compare_from,
    compare_to,
    comparison,
    date,
    filters,
    from,
    labels,
    match_day_of_week,
    period,
    to,
    with_imported,
    site,
    expandedSegment
  ])

  useClearExpandedSegmentModeOnFilterClear({ expandedSegment, query })

  useEffect(() => {
    const newValue = {
      is_filtered_by_goal: hasConversionGoalFilter({ filters }),
      is_filtered_by_page: getFiltersByKeyPrefix({ filters }, 'page').length > 0
    }
    setMetricsInfoValue(newValue)
    // need to handle filters inside segment, when applying a segment...
  }, [setMetricsInfoValue, filters])

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
    <QueryContext.Provider
      value={{
        query,
        otherSearch,
        expandedSegment
      }}
    >
      {children}
    </QueryContext.Provider>
  )
}
