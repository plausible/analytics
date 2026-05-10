import {
  QueryFilters,
  useInfiniteQuery,
  useQueryClient
} from '@tanstack/react-query'
import { DashboardState } from '../dashboard-state'
import { PlausibleSite } from '../site-context'
import {
  createStatsQuery,
  NonTimeDimension,
  ReportParams
} from '../stats-query'
import { useEffect } from 'react'
import { cleanToPageOne, getStaleTime, PAGINATION_LIMIT } from './api-client'
import { QueryApiResponse, stats } from '../api'
import { addDimensionSearchFilter } from '../stats/breakdowns'

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
