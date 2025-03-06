/** @format */
import { DashboardQuery } from './query'
import { formatISO } from './util/date'
import { serializeApiFilters } from './util/filters'

let abortController = new AbortController()
let SHARED_LINK_AUTH: null | string = null

export class ApiError extends Error {
  payload: unknown
  constructor(message: string, payload: unknown) {
    super(message)
    this.name = 'ApiError'
    this.payload = payload
  }
}

function serialize(obj: Record<string, string | boolean | number>) {
  const str: string[] = []
  /* eslint-disable-next-line no-prototype-builtins */
  for (const p in obj)
    if (obj.hasOwnProperty(p)) {
      str.push(`${encodeURIComponent(p)}=${encodeURIComponent(obj[p])}`)
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

export function serializeQuery(
  query: DashboardQuery,
  extraQuery: unknown[] = []
) {
  const queryObj: Record<string, string> = {}
  if (query.period) {
    queryObj.period = query.period
  }
  if (query.date) {
    queryObj.date = formatISO(query.date)
  }
  if (query.from) {
    queryObj.from = formatISO(query.from)
  }
  if (query.to) {
    queryObj.to = formatISO(query.to)
  }
  if (query.filters) {
    queryObj.filters = serializeApiFilters(query.filters)
  }
  if (query.with_imported) {
    queryObj.with_imported = String(query.with_imported)
  }

  if (query.comparison) {
    queryObj.comparison = query.comparison
    queryObj.compare_from = query.compare_from
      ? formatISO(query.compare_from)
      : undefined
    queryObj.compare_to = query.compare_to
      ? formatISO(query.compare_to)
      : undefined
    queryObj.match_day_of_week = String(query.match_day_of_week)
  }

  Object.assign(queryObj, ...extraQuery)

  return serialize(queryObj)
}

function getHeaders(): Record<string, string> {
  return SHARED_LINK_AUTH ? { 'X-Shared-Link-Auth': SHARED_LINK_AUTH } : {}
}

async function handleApiResponse(response: Response) {
  const payload = await response.json()
  if (!response.ok) {
    throw new ApiError(payload.error, payload)
  }

  return payload
}

function getSharedLinkQueryParams(): Record<string, string> {
  return SHARED_LINK_AUTH ? { auth: SHARED_LINK_AUTH } : {}
}

export async function get(
  url: string,
  query?: DashboardQuery,
  ...extraQueryParams: unknown[]
) {
  const sharedLinkParams = getSharedLinkQueryParams()

  const queryString = query
    ? serializeQuery(query, [...extraQueryParams, sharedLinkParams])
    : new URLSearchParams(sharedLinkParams).toString()

  const response = await fetch(queryString ? `${url}?${queryString}` : url, {
    signal: abortController.signal,
    headers: { ...getHeaders(), Accept: 'application/json' }
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
  const sharedLinkParams = getSharedLinkQueryParams()
  const queryString = new URLSearchParams(sharedLinkParams).toString()
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
  return handleApiResponse(response)
}
