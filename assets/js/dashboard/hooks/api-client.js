import { useEffect } from "react"
import { useQueryClient, useInfiniteQuery } from "@tanstack/react-query"
import * as api from "../api"

const LIMIT = 10 // FOR DEBUGGING

/**
 * A wrapper for the React Query library. Constructs the necessary options
 * (including pagination config) to pass into the `useInfiniteQuery` hook.
 *
 * ### Required props
 *
 * @param {Array} key - The key under which the global "query" instance will live.
 *   Should be passed as a list of two elements - `[endpoint, { query }]`. The object
 *   can also contain additional values (such as `search`) to be used by:
 *   1) React Query, to determine the uniqueness of the query instance
 *   2) the `getRequestParams` function to build the request params.
 *
 * @param {Function} getRequestParams - A function that takes the `key` prop as an
 *   argument, and returns `[query, params]` which will be used by `queryFn` that
 *   actually calls the API.
 *
 * ### Optional props
 *
 * @param {Function} [afterFetchData] - A function to call after data has been fetched.
 *   Receives the API response as an argument.
 *
 * @param {Function} [afterFetchNextPage] - A function to call after the next page has
 *   been fetched. Receives the API response as an argument.
 */

export function useAPIClient(props) {
  const {key, getRequestParams, afterFetchData, afterFetchNextPage} = props
  const [endpoint] = key
  const queryClient = useQueryClient()

  const queryFn = async ({ pageParam, queryKey }) => {
    const [query, params] = getRequestParams(queryKey)
    params.limit = LIMIT
    params.page = pageParam

    const response = await api.get(endpoint, query, params)
    
    if (pageParam === 1 && typeof afterFetchData === 'function') {
      afterFetchData(response)
    }

    if (pageParam > 1 && typeof afterFetchNextPage === 'function') {
      afterFetchNextPage(response)
    }

    return response.results
  }

  // During the cleanup phase, make sure only the first page of results
  // is cached under any `queryKey` containing this endpoint.
  useEffect(() => {
    const key = [endpoint]
    return () => {
      queryClient.setQueriesData(key, (data) => {
        if (data?.pages?.length) {
          return {
            pages: data.pages.slice(0, 1),
            pageParams: data.pageParams.slice(0, 1),
          }  
        }
      })  
    }
  }, [queryClient, endpoint])

  const getNextPageParam = (lastPageResults, _, lastPageIndex) => {
    return lastPageResults.length === LIMIT ? lastPageIndex + 1 : null
  }
  const defaultInitialPageParam = 1
  const initialPageParam = props.initialPageParam === undefined ? defaultInitialPageParam : props.initialPageParam

  return useInfiniteQuery({
    queryKey: key,
    queryFn,
    getNextPageParam,
    initialPageParam,
    placeholderData: (previousData) => previousData,
  })
}