import { useEffect } from 'react'
import {
  useQueryClient,
  useInfiniteQuery,
  QueryFilters
} from '@tanstack/react-query'
import * as api from '../api'
import { DashboardState } from '../dashboard-state'
import { DashboardPeriod } from '../dashboard-time-periods'
import { Dayjs } from 'dayjs'
import { REALTIME_UPDATE_TIME_MS } from '../util/realtime-update-timer'

// defines when queries that don't include the current time should be refetched
const HISTORICAL_RESPONSES_STALE_TIME_MS = 12 * 60 * 60 * 1000

// how many items per page for breakdown modals
const PAGINATION_LIMIT = 100

/** full endpoint URL */
type Endpoint = string

type PaginatedQueryKeyBase = [Endpoint, { dashboardState: DashboardState }]

type GetRequestParams<TKey extends PaginatedQueryKeyBase> = (
  k: TKey
) => [DashboardState, Record<string, unknown>]

/**
 * Hook that fetches the first page from the defined GET endpoint on mount,
 * then subsequent pages when component calls fetchNextPage.
 * Stores fetched pages locally, but only the first page of the results.
 */
export function usePaginatedGetAPI<
  TResponse extends { results: unknown[] },
  TKey extends PaginatedQueryKeyBase = PaginatedQueryKeyBase
>({
  key,
  getRequestParams,
  afterFetchData,
  afterFetchNextPage,
  initialPageParam = 1
}: {
  key: TKey
  getRequestParams: GetRequestParams<TKey>
  afterFetchData?: (response: TResponse) => void
  afterFetchNextPage?: (response: TResponse) => void
  initialPageParam?: number
}) {
  const [endpoint] = key
  const queryClient = useQueryClient()

  useEffect(() => {
    const onDismountCleanToPageOne = () => {
      const queryKeyToClean = [endpoint] as QueryFilters
      queryClient.setQueriesData(queryKeyToClean, cleanToPageOne)
    }
    return onDismountCleanToPageOne
  }, [queryClient, endpoint])

  return useInfiniteQuery({
    queryKey: key,
    queryFn: async ({ pageParam, queryKey }): Promise<TResponse['results']> => {
      const [dashboardState, params] = getRequestParams(queryKey)

      const response: TResponse = await api.get(endpoint, dashboardState, {
        ...params,
        limit: PAGINATION_LIMIT,
        page: pageParam
      })

      if (
        pageParam === initialPageParam &&
        typeof afterFetchData === 'function'
      ) {
        afterFetchData(response)
      }

      if (
        pageParam > initialPageParam &&
        typeof afterFetchNextPage === 'function'
      ) {
        afterFetchNextPage(response)
      }

      return response.results
    },
    getNextPageParam: (lastPageResults, _, lastPageIndex) => {
      return lastPageResults.length === PAGINATION_LIMIT
        ? lastPageIndex + 1
        : null
    },
    initialPageParam,
    placeholderData: (previousData) => previousData
  })
}

export const cleanToPageOne = <
  T extends { pages: unknown[]; pageParams: unknown[] }
>(
  data?: T
) => {
  if (data?.pages?.length) {
    return {
      pages: data.pages.slice(0, 1),
      pageParams: data.pageParams.slice(0, 1)
    }
  }
  return data
}

export const getStaleTime = (
  /** the start of the current day */
  startOfDay: Dayjs,
  {
    period,
    from,
    to,
    date
  }: Pick<DashboardState, 'period' | 'from' | 'to' | 'date'>
): number => {
  if (DashboardPeriod.custom && to && from) {
    // historical
    if (from.isBefore(startOfDay) && to.isBefore(startOfDay)) {
      return HISTORICAL_RESPONSES_STALE_TIME_MS
    }
    // period includes now
    if (to.diff(from, 'days') < 7) {
      return 5 * 60 * 1000
    }
    if (to.diff(from, 'months') < 1) {
      return 15 * 60 * 1000
    }
    if (to.diff(from, 'months') < 12) {
      return 60 * 60 * 1000
    }
    return 3 * 60 * 60 * 1000
  }

  const historical = date?.isBefore(startOfDay)
  if (historical) {
    return HISTORICAL_RESPONSES_STALE_TIME_MS
  }

  switch (period) {
    case DashboardPeriod.realtime:
      return REALTIME_UPDATE_TIME_MS
    case DashboardPeriod['24h']:
    case DashboardPeriod.day:
      return 5 * 60 * 1000
    case DashboardPeriod['7d']:
      return 15 * 60 * 1000
    case DashboardPeriod['28d']:
    case DashboardPeriod['30d']:
    case DashboardPeriod['91d']:
    case DashboardPeriod['6mo']:
      return 60 * 60 * 1000
    case DashboardPeriod['12mo']:
    case DashboardPeriod.year:
      return 3 * 60 * 60 * 1000
    case DashboardPeriod.all:
    default:
      // err on the side of less caching,
      // to avoid the user refresheshing
      return 15 * 60 * 1000
  }
}
