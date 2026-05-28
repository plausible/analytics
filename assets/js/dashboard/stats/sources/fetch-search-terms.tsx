import { InfiniteData, useInfiniteQuery, useQuery } from '@tanstack/react-query'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { DashboardState } from '../../dashboard-state'
import * as api from '../../api'
import { ApiError } from '../../api'
import * as url from '../../util/url'
import { getStaleTime, PAGINATION_LIMIT } from '../../hooks/api-client'

const INDEX_SEARCH_TERMS_REPORT_ID = 'index-search-terms'
const DETAILED_SEARCH_TERMS_REPORT_ID = 'detailed-search-terms'
const SEARCH_TERMS_ENDPOINT = '/google-search-terms'

export const GOOGLE_SEARCH_TERMS_DETAILS_PATH = 'referrers/Google'

type IndexSearchTermsQueryKey = [
  typeof INDEX_SEARCH_TERMS_REPORT_ID,
  { dashboardState: DashboardState }
]

type DetailedSearchTermsQueryKey = [
  typeof DETAILED_SEARCH_TERMS_REPORT_ID,
  { dashboardState: DashboardState; search?: string }
]

export type SearchTermsResultItem = {
  name: string
  position: number
  visitors: number
  ctr: number
  impressions: number
}
export type SearchTermsSuccessResponse = {
  results: SearchTermsResultItem[]
}

export type SearchTermsErrorCode =
  | 'not_configured'
  | 'unsupported_filters'
  | 'period_too_recent'
export type SearchTermsErrorPayload = {
  error_code: SearchTermsErrorCode
  is_admin: boolean
}

export function useIndexGoogleSearchTermsQuery({
  enabled
}: {
  enabled: boolean
}) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const searchTermsQueryKey: IndexSearchTermsQueryKey = [
    INDEX_SEARCH_TERMS_REPORT_ID,
    { dashboardState }
  ]

  return useQuery<
    SearchTermsSuccessResponse,
    ApiError,
    SearchTermsSuccessResponse,
    IndexSearchTermsQueryKey
  >({
    queryKey: searchTermsQueryKey,
    enabled: enabled,
    retry: false,
    queryFn: ({ queryKey }) => {
      return api.get(
        url.apiPath(site, SEARCH_TERMS_ENDPOINT),
        queryKey[1].dashboardState
      )
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey }) => {
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...queryKey[1].dashboardState
      })
    }
  })
}

export function useDetailedGoogleSearchTermsQuery({
  search
}: {
  search?: string
}) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const searchTermsQueryKey: DetailedSearchTermsQueryKey = [
    DETAILED_SEARCH_TERMS_REPORT_ID,
    { dashboardState, search }
  ]

  return useInfiniteQuery<
    SearchTermsSuccessResponse,
    ApiError,
    InfiniteData<SearchTermsSuccessResponse>,
    DetailedSearchTermsQueryKey,
    number
  >({
    queryKey: searchTermsQueryKey,
    retry: false,
    queryFn: ({ pageParam, queryKey }) => {
      const { dashboardState, search } = queryKey[1]

      return api.get(url.apiPath(site, SEARCH_TERMS_ENDPOINT), dashboardState, {
        detailed: true,
        search: search,
        limit: PAGINATION_LIMIT,
        page: pageParam
      })
    },
    placeholderData: (previousData) => previousData,
    getNextPageParam: (lastPageResults, _, lastPageIndex) => {
      return lastPageResults.results.length === PAGINATION_LIMIT
        ? lastPageIndex + 1
        : null
    },
    initialPageParam: 0,
    staleTime: ({ queryKey }) => {
      const [_, opts] = queryKey
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...opts.dashboardState
      })
    }
  })
}
