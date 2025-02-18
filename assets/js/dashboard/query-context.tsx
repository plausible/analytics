/* @format */
import React, {
  createContext,
  useMemo,
  useContext,
  ReactNode,
  useEffect,
  useState
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
import { useAppNavigate } from './navigation/use-app-navigate'
import { SegmentModalState } from './segments/segment-expanded-context'

const queryContextDefaultValue = {
  query: queryDefaultValue,
  otherSearch: {} as Record<string, unknown>,
  expandedSegment: null as
    | (SavedSegment & { segment_data: SegmentData })
    | null,
  modal: null as SegmentModalState,
  setModal: (_modal: SegmentModalState) => {}
}

export type QueryContextValue = typeof queryContextDefaultValue

const QueryContext = createContext(queryContextDefaultValue)

export const useQueryContext = () => {
  return useContext(QueryContext)
}

function useDefiniteLocationState<T>(key: string) {
  const location = useLocation()
  const rawState = useMemo(() => location.state ?? {}, [location.state])

  const navigate = useAppNavigate()
  // Initialize with location.state if defined, otherwise null.
  const [definiteValue, setDefiniteValue] = useState<T | null>(
    rawState[key] === undefined ? null : (rawState[key] as T)
  )

  // Effect: Whenever explicitState changes, sync it into location.state.
  useEffect(() => {
    // Normalize location.state so that undefined is treated as null.
    if (rawState[key] === undefined) {
      navigate({
        search: (s) => s,
        state: { ...rawState, [key]: definiteValue },
        replace: true
      })
    }
  }, [definiteValue, rawState, navigate, key])

  useEffect(() => {
    if (rawState[key] !== undefined && rawState[key] !== definiteValue) {
      setDefiniteValue(rawState[key] as T)
    }
  }, [rawState, definiteValue, key])

  return { location, definiteValue }
}

export default function QueryContextProvider({
  children
}: {
  children: ReactNode
}) {
  const { location, definiteValue: expandedSegment } = useDefiniteLocationState<
    SavedSegment & { segment_data: SegmentData }
  >('expandedSegment')
  const navigate = useAppNavigate()
  const site = useSiteContext()

  const [modal, setModal] = useState<SegmentModalState>(null)

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

  useEffect(() => {
    // clear edit mode on clearing all filters or removing last filter
    if (!!expandedSegment && !query.filters.length) {
      navigate({
        search: (s) => s,
        state: {
          expandedSegment: null
        },
        replace: true
      })
    }
  }, [query.filters, expandedSegment, navigate])

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
        expandedSegment,
        modal,
        setModal
      }}
    >
      {children}
    </QueryContext.Provider>
  )
}
