import {
  QueryFilters,
  useInfiniteQuery,
  useQuery,
  useQueryClient,
  UseQueryResult
} from '@tanstack/react-query'
import { DashboardState } from '../dashboard-state'
import { PlausibleSite } from '../site-context'
import {
  createStatsQuery,
  NonTimeDimension,
  ReportParams,
  StatsQuery
} from '../stats-query'
import { useEffect, useState } from 'react'
import { cleanToPageOne, getStaleTime, PAGINATION_LIMIT } from './api-client'
import { ExtraContext, QueryApiResponse, stats } from '../api'
import { addDimensionSearchFilter } from '../stats/breakdowns'
import { DashboardPeriod } from '../dashboard-time-periods'
import { hasConversionGoalFilter, isRealTimeDashboard } from '../util/filters'
import { MainGraphResponse } from '../stats/graph/fetch-main-graph'

export type StatsReportId =
  | 'top-stats'
  | 'main-graph'
  | NonTimeDimension
  | `${NonTimeDimension},${NonTimeDimension}`

export type StatsReportQueryKey = [
  StatsReportId,
  {
    dashboardState: DashboardState
    reportParams: ReportParams
    search?: string
    searchDimension?: NonTimeDimension
  }
]

type ReportOpts = {
  enabled?: boolean
  getStatsQuery?: (queryKey: StatsReportQueryKey) => StatsQuery
}

function withExtraContext<T extends QueryApiResponse | MainGraphResponse>(
  response: T,
  dashboardState: DashboardState
): T {
  const extraContext: ExtraContext = {
    isRealtime: isRealTimeDashboard(dashboardState),
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  }
  return { ...response, extraContext } as T
}

export const defaultGetStatsQuery = (
  queryKey: StatsReportQueryKey
): StatsQuery => {
  const [_, keyOpts] = queryKey
  return createStatsQuery(keyOpts.dashboardState, keyOpts.reportParams)
}

/**
 * Hook for POST /api/stats/:domain/query requests, calling TanStack useQuery
 * under the hood. Also sets up automatic realtime updates and allows passing
 * `opts = {enabled: false}` to prevent fetching anything, e.g. for until the
 * report is visible.
 */
export function useQueryApi<
  TResponse extends QueryApiResponse | MainGraphResponse = QueryApiResponse
>(
  site: PlausibleSite,
  statsReportQueryKey: StatsReportQueryKey,
  opts?: ReportOpts
): {
  apiState: UseQueryResult<TResponse>
  isRealtimeSilentUpdate: boolean
} {
  const statsReportId = statsReportQueryKey[0]
  const isRealtime =
    statsReportQueryKey[1].dashboardState.period === DashboardPeriod.realtime
  const [isRealtimeSilentUpdate, setIsRealtimeSilentUpdate] = useState(false)

  const enabled = opts?.enabled ?? true
  const getStatsQuery = opts?.getStatsQuery ?? defaultGetStatsQuery

  const queryClient = useQueryClient()

  const apiState = useQuery({
    queryKey: statsReportQueryKey,
    enabled,
    queryFn: async ({ queryKey }) => {
      const [_, keyOpts] = queryKey
      const response = await stats<TResponse>(site, getStatsQuery(queryKey))
      return withExtraContext(response, keyOpts.dashboardState)
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey }) => {
      const [_, keyOpts] = queryKey
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...keyOpts.dashboardState
      })
    }
  })

  useEffect(() => {
    if (!enabled || !isRealtime) return

    const onTick = () => {
      setIsRealtimeSilentUpdate(true)
      queryClient.invalidateQueries({
        predicate: ({ queryKey }) => {
          const [id, keyOpts] = queryKey as StatsReportQueryKey
          return (
            id === statsReportId &&
            keyOpts.dashboardState.period === DashboardPeriod.realtime
          )
        }
      })
    }

    document.addEventListener('tick', onTick)

    return () => {
      document.removeEventListener('tick', onTick)
    }
  }, [queryClient, isRealtime, statsReportId, enabled])

  useEffect(() => {
    if (!apiState.isRefetching) {
      setIsRealtimeSilentUpdate(false)
    }
  }, [apiState.isRefetching])

  useEffect(() => {
    if (!isRealtime) {
      setIsRealtimeSilentUpdate(false)
    }
  }, [isRealtime])

  return { apiState, isRealtimeSilentUpdate }
}

/**
 * Hook for paginated POST /api/stats/:domain/query requests (i.e. Details views).
 * Optionally supports search, appending a `['contains', dimensions[0], search]`
 * filter to the query filters.
 */
export function useSearchAndPaginateQueryAPI(
  site: PlausibleSite,
  statsReportQueryKey: StatsReportQueryKey,
  opts?: Pick<ReportOpts, 'getStatsQuery'>
) {
  const queryClient = useQueryClient()
  const key = statsReportQueryKey[0]
  const { dashboardState } = statsReportQueryKey[1]
  const getStatsQuery = opts?.getStatsQuery ?? defaultGetStatsQuery

  useEffect(() => {
    return () => {
      const tanstackQueryFilters: QueryFilters = {
        predicate: ({ queryKey }) => queryKey[0] === key
      }
      queryClient.setQueriesData(tanstackQueryFilters, cleanToPageOne)
    }
  }, [queryClient, key])

  return useInfiniteQuery({
    queryKey: statsReportQueryKey,
    queryFn: async ({ pageParam, queryKey }): Promise<QueryApiResponse> => {
      const { dashboardState, reportParams, search, searchDimension } =
        queryKey[1]

      let statsQuery = getStatsQuery(queryKey)

      if (search && search !== '') {
        const searchBy =
          searchDimension ?? (reportParams.dimensions[0] as NonTimeDimension)
        statsQuery = addDimensionSearchFilter(statsQuery, searchBy, search)
      }

      const response = await stats<QueryApiResponse>(site, {
        ...statsQuery,
        pagination: { limit: PAGINATION_LIMIT, offset: pageParam as number }
      })
      return withExtraContext(response, dashboardState)
    },
    getNextPageParam: (lastPage, _, lastPageParam) => {
      return lastPage.results.length === PAGINATION_LIMIT
        ? (lastPageParam as number) + PAGINATION_LIMIT
        : null
    },
    staleTime: () =>
      getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...dashboardState
      }),
    initialPageParam: 0,
    placeholderData: (previousData) => previousData
  })
}
