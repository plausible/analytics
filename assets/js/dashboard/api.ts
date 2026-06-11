import { Metric } from './stats/metrics'
import { DashboardState } from './dashboard-state'
import { PlausibleSite } from './site-context'
import { StatsQuery } from './stats-query'
import { formatISO } from './util/date'
import { serializeApiFilters } from './util/filters'
import * as url from './util/url'
import { MainGraphResponse } from './stats/graph/fetch-main-graph'
import { CsvExportRequestBody } from './stats/csv-export/csv-export-body'
import { maybeReloadForApiVersion } from './util/url-search-params'

let abortController = new AbortController()
let SHARED_LINK_AUTH: null | string = null

export type RevenueMetricValue = {
  short: string
  value: number
  long: string
  currency: string
}

export type MetricValue = null | number | RevenueMetricValue

export type QueryResultQuery = {
  metrics: Metric[]
  dimensions: string[]
  date_range: [string, string]
  comparison_date_range?: [string, string] | null
}

export type QueryResultMeta = {
  metric_warnings?: Record<string, Record<string, string>>
  imports_included?: boolean
  imports_skip_reason?: string
}

export type QueryResultRow = {
  metrics: Array<MetricValue>
  dimensions: Array<string>
  comparison?: { metrics: Array<number>; change: Array<number> }
}

// Added client-side in the queryFn before storing to TanStack cache.
// Needed to make sure that the time/metric labels we're constructing
// in stats reports are in sync with the dashboardState that was used
// to make that query. Otherwise, relying on current dashboardState
// while rendering previous (placeholder) data, it'd be out of sync.
export type ExtraContext = {
  isRealtime: boolean
  hasConversionGoalFilter: boolean
}

export type QueryApiResponse = {
  query: QueryResultQuery
  meta: QueryResultMeta
  results: QueryResultRow[]
  extraContext: ExtraContext
}

export class ApiError extends Error {
  payload: unknown
  status: number
  constructor(message: string, payload: unknown, status: number) {
    super(message)
    this.name = 'ApiError'
    this.payload = payload
    this.status = status
  }
}

function serializeUrlParams(params: Record<string, string | boolean | number>) {
  const str: string[] = []
  for (const p in params)
    if (params.hasOwnProperty(p)) {
      str.push(`${encodeURIComponent(p)}=${encodeURIComponent(params[p])}`)
    }
  return str.join('&')
}

export function setSharedLinkAuth(auth: string) {
  SHARED_LINK_AUTH = auth
}

export function cancelAll() {
  abortController.abort()
  abortController = new AbortController()
}

export function dashboardStateToSearchParams(
  dashboardState: DashboardState,
  extraQuery: unknown[] = []
): string {
  return serializeUrlParams(dashboardStateToParams(dashboardState, extraQuery))
}

export function dashboardStateToParams(
  dashboardState: DashboardState,
  extraQuery: unknown[] = []
): Record<string, string> {
  const queryObj: Record<string, string> = {}
  if (dashboardState.period) {
    queryObj.period = dashboardState.period
  }
  if (dashboardState.date) {
    queryObj.date = formatISO(dashboardState.date)
  }
  if (dashboardState.from) {
    queryObj.from = formatISO(dashboardState.from)
  }
  if (dashboardState.to) {
    queryObj.to = formatISO(dashboardState.to)
  }
  if (dashboardState.filters) {
    queryObj.filters = serializeApiFilters(dashboardState.filters)
  }
  if (dashboardState.with_imported) {
    queryObj.with_imported = String(dashboardState.with_imported)
  }

  if (dashboardState.comparison) {
    queryObj.comparison = dashboardState.comparison
    queryObj.compare_from = dashboardState.compare_from
      ? formatISO(dashboardState.compare_from)
      : undefined
    queryObj.compare_to = dashboardState.compare_to
      ? formatISO(dashboardState.compare_to)
      : undefined
    queryObj.match_day_of_week = String(dashboardState.match_day_of_week)
  }

  const sharedLinkParams = getSharedLinkSearchParams()
  if (sharedLinkParams.auth) {
    queryObj.auth = sharedLinkParams.auth
  }

  Object.assign(queryObj, ...extraQuery)

  return queryObj
}

function getHeaders(): Record<string, string> {
  return SHARED_LINK_AUTH ? { 'X-Shared-Link-Auth': SHARED_LINK_AUTH } : {}
}

async function throwApiErrorIfNotOk(response: Response) {
  if (!response.ok) {
    const payload = await response.json()
    throw new ApiError(payload.error, payload, response.status)
  }
}

async function handleApiResponse(
  response: Response,
  opts: Record<'idempotent', boolean> = { idempotent: true }
) {
  if (opts.idempotent) {
    maybeReloadForApiVersion(window.location, response.headers)
  }

  await throwApiErrorIfNotOk(response)
  return response.json()
}

function getSharedLinkSearchParams(): Record<string, string> {
  return SHARED_LINK_AUTH ? { auth: SHARED_LINK_AUTH } : {}
}

export async function stats<
  TResponse extends QueryApiResponse | MainGraphResponse
>(site: PlausibleSite, statsQuery: StatsQuery) {
  const sharedLinkParams = getSharedLinkSearchParams()
  const queryString = sharedLinkParams.auth
    ? new URLSearchParams(sharedLinkParams).toString()
    : ''
  const path = url.apiPath(site, '/query')
  const response = await fetch(queryString ? `${path}?${queryString}` : path, {
    method: 'POST',
    signal: abortController.signal,
    headers: {
      ...getHeaders(),
      'Content-Type': 'application/json',
      Accept: 'application/json'
    },
    body: JSON.stringify(statsQuery)
  })

  return (await handleApiResponse(response)) as TResponse
}

export async function csvExport(
  site: PlausibleSite,
  body: CsvExportRequestBody
): Promise<Blob> {
  const sharedLinkParams = getSharedLinkSearchParams()
  const queryString = sharedLinkParams.auth
    ? new URLSearchParams(sharedLinkParams).toString()
    : ''
  const path = url.apiPath(site, '/export')
  const response = await fetch(queryString ? `${path}?${queryString}` : path, {
    method: 'POST',
    headers: { ...getHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  })
  await throwApiErrorIfNotOk(response)
  return response.blob()
}

export async function get(
  url: string,
  dashboardState?: DashboardState,
  ...extraQueryParams: unknown[]
) {
  const queryString = dashboardState
    ? dashboardStateToSearchParams(dashboardState, [...extraQueryParams])
    : serializeUrlParams(getSharedLinkSearchParams())

  const response = await fetch(queryString ? `${url}?${queryString}` : url, {
    signal: abortController.signal,
    headers: { ...getHeaders(), Accept: 'application/json' }
  })

  return handleApiResponse(response)
}

export async function post(
  url: string,
  dashboardState: DashboardState,
  ...extraBodyParams: unknown[]
) {
  const queryString = serializeUrlParams(getSharedLinkSearchParams())
  const response = await fetch(queryString ? `${url}?${queryString}` : url, {
    method: 'POST',
    signal: abortController.signal,
    headers: {
      ...getHeaders(),
      'Content-Type': 'application/json',
      Accept: 'application/json'
    },
    body: JSON.stringify(
      dashboardStateToParams(dashboardState, [...extraBodyParams])
    )
  })

  return handleApiResponse(response)
}

export const mutation = async <
  TBody extends Record<string, unknown> = Record<string, unknown>
>(
  url: string,
  options:
    | { body: TBody; method: 'PATCH' | 'PUT' | 'POST' }
    | { method: 'DELETE' }
) => {
  const queryString = serializeUrlParams(getSharedLinkSearchParams())
  const fetchOptions =
    options.method === 'DELETE'
      ? {}
      : {
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(options.body)
        }
  const response = await fetch(queryString ? `${url}?${queryString}` : url, {
    method: options.method,
    headers: {
      ...getHeaders(),
      ...fetchOptions.headers,
      Accept: 'application/json'
    },
    body: fetchOptions.body,
    signal: abortController.signal
  })
  return handleApiResponse(response, { idempotent: false })
}
