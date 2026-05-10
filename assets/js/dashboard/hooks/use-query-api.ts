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
  ReportParams
} from '../stats-query'
import { useEffect, useState } from 'react'
import { cleanToPageOne, getStaleTime, PAGINATION_LIMIT } from './api-client'
import { QueryApiResponse, stats } from '../api'
import { addDimensionSearchFilter } from '../stats/breakdowns'
import { DashboardPeriod } from '../dashboard-time-periods'

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
  }
]

/**
 * Hook for POST /api/stats/:domain/query requests, calling TanStack useQuery
 * under the hood. Also sets up automatic realtime updates and allows passing
 * `opts = {enabled: false}` to prevent fetching anything, e.g. for until the
 * report is visible.
 */
export function useQueryApi(
  site: PlausibleSite,
  statsReportQueryKey: StatsReportQueryKey,
  opts: { enabled: boolean } = { enabled: true }
): {
  apiState: UseQueryResult<QueryApiResponse>
  isRealtimeSilentUpdate: boolean
} {
  const statsReportId = statsReportQueryKey[0]
  const isRealtime =
    statsReportQueryKey[1].dashboardState.period === DashboardPeriod.realtime
  const [isRealtimeSilentUpdate, setIsRealtimeSilentUpdate] = useState(false)

  const queryClient = useQueryClient()

  const apiState = useQuery({
    queryKey: statsReportQueryKey,
    enabled: opts.enabled,
    queryFn: ({ queryKey }) => {
      const [_, keyOpts] = queryKey as StatsReportQueryKey
      const statsQuery = createStatsQuery(
        keyOpts.dashboardState,
        keyOpts.reportParams
      )
      return stats(site, statsQuery)
    },
    staleTime: ({ queryKey }) => {
      const [_, keyOpts] = queryKey as StatsReportQueryKey
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...keyOpts.dashboardState
      })
    }
  })

  useEffect(() => {
    if (!opts.enabled || !isRealtime) return

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
  }, [queryClient, isRealtime, statsReportId, opts.enabled])

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
export function useSearchAndPaginateQueryAPI({
  site,
  statsReportQueryKey
}: {
  site: PlausibleSite
  statsReportQueryKey: StatsReportQueryKey
}) {
  const queryClient = useQueryClient()
  const key = statsReportQueryKey[0]
  const { dashboardState } = statsReportQueryKey[1]

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
      const { dashboardState, reportParams, search } = queryKey[1]

      let statsQuery = createStatsQuery(dashboardState, reportParams)

      if (search && search !== '') {
        const searchBy = reportParams.dimensions[0]
        statsQuery = addDimensionSearchFilter(statsQuery, searchBy, search)
      }

      return stats(site, {
        ...statsQuery,
        pagination: { limit: PAGINATION_LIMIT, offset: pageParam as number }
      })
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
