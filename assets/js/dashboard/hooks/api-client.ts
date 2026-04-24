import { useEffect } from 'react'
import {
  useQueryClient,
  useInfiniteQuery,
  QueryFilters
} from '@tanstack/react-query'
import * as api from '../api'
import { DashboardState } from '../dashboard-state'
import {
  DashboardPeriod,
  DashboardTimeSettings,
  isHistoricalPeriod
} from '../dashboard-time-periods'
import { REALTIME_UPDATE_TIME_MS } from '../util/realtime-update-timer'
import { Interval, validIntervals } from '../stats/graph/intervals'

// define (in ms) when query API responses should become stale
export const CACHE_TTL_REALTIME = REALTIME_UPDATE_TIME_MS
export const CACHE_TTL_SHORT_ONGOING = 5 * 60 * 1000 // 5 minutes
export const CACHE_TTL_LONG_ONGOING = 60 * 60 * 1000 // 1 hour
export const CACHE_TTL_HISTORICAL = 12 * 60 * 60 * 1000 // 12 hours

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
  siteTimezoneOffset,
  siteStatsBegin,
  key,
  getRequestParams,
  afterFetchData,
  afterFetchNextPage,
  initialPageParam = 1
}: {
  siteTimezoneOffset: DashboardTimeSettings['siteTimezoneOffset']
  siteStatsBegin: DashboardTimeSettings['siteStatsBegin']
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
    staleTime: ({ queryKey }) => {
      const [_, opts] = queryKey
      return getStaleTime({
        siteTimezoneOffset: siteTimezoneOffset,
        siteStatsBegin: siteStatsBegin,
        ...opts.dashboardState
      })
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

/**
 * Returns the time-to-live for cached query API responses based on the given DashboardTimeSettings.
 *
 * - For a realtime dashboard: {@link CACHE_TTL_REALTIME}
 * - For any historical period (i.e. does not include today): {@link CACHE_TTL_HISTORICAL}
 * - For a period that includes today, supporting 'day' or shorter interval: {@link CACHE_TTL_SHORT_ONGOING}
 * - For a period that includes today, too long to support 'day' interval: {@link CACHE_TTL_LONG_ONGOING}
 */
export const getStaleTime = (props: DashboardTimeSettings): number => {
  if (
    [DashboardPeriod.realtime, DashboardPeriod.realtime_30m].includes(
      props.period
    )
  ) {
    return CACHE_TTL_REALTIME
  }

  if (isHistoricalPeriod(props)) {
    return CACHE_TTL_HISTORICAL
  }

  const availableIntervals = validIntervals(props)

  if (
    availableIntervals.includes(Interval.day) ||
    availableIntervals.includes(Interval.hour) ||
    availableIntervals.includes(Interval.minute)
  ) {
    return CACHE_TTL_SHORT_ONGOING
  } else {
    return CACHE_TTL_LONG_ONGOING
  }
}
