/** @format */

import { useEffect } from 'react'
import {
  useQueryClient,
  useInfiniteQuery,
  QueryFilters
} from '@tanstack/react-query'
import * as api from '../api'
import { DashboardQuery } from '../query'
import { useSiteContext } from '../site-context'

const LIMIT = 100

/** full endpoint URL */
type Endpoint = string

type PaginatedQueryKeyBase = [Endpoint, { query: DashboardQuery }]

type GetRequestParams<TKey extends PaginatedQueryKeyBase> = (
  k: TKey
) => [DashboardQuery, Record<string, unknown>]

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
  const site = useSiteContext()

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
      const [query, params] = getRequestParams(queryKey)

      const response: TResponse = await api.get(site, endpoint, query, {
        ...params,
        limit: LIMIT,
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
      return lastPageResults.length === LIMIT ? lastPageIndex + 1 : null
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
