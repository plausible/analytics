import { formatISO } from './util/date'
import { serializeApiFilters } from './util/filters'

let abortController = new AbortController()
let SHARED_LINK_AUTH = null

class ApiError extends Error {
  constructor(message, payload) {
    super(message)
    this.name = "ApiError"
    this.payload = payload
  }
}

function serialize(obj) {
  var str = [];
  for (var p in obj)
    /* eslint-disable-next-line no-prototype-builtins */
    if (obj.hasOwnProperty(p)) {
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
    }
  return str.join("&");
}

export function setSharedLinkAuth(auth) {
  SHARED_LINK_AUTH = auth
}

export function cancelAll() {
  abortController.abort()
  abortController = new AbortController()
}

export function serializeQuery(query, extraQuery = []) {
  const queryObj = {}
  if (query.period) { queryObj.period = query.period }
  if (query.date) { queryObj.date = formatISO(query.date) }
  if (query.from) { queryObj.from = formatISO(query.from) }
  if (query.to) { queryObj.to = formatISO(query.to) }
  if (query.filters) { queryObj.filters = serializeApiFilters(query.filters) }
  if (query.with_imported) { queryObj.with_imported = query.with_imported }
  if (SHARED_LINK_AUTH) { queryObj.auth = SHARED_LINK_AUTH }

  if (query.comparison) {
    queryObj.comparison = query.comparison
    queryObj.compare_from = query.compare_from ? formatISO(query.compare_from) : undefined
    queryObj.compare_to = query.compare_to ? formatISO(query.compare_to) : undefined
    queryObj.match_day_of_week = query.match_day_of_week
  }

  Object.assign(queryObj, ...extraQuery)

  return '?' + serialize(queryObj)
}

export function get(url, query = {}, ...extraQuery) {
  const headers = SHARED_LINK_AUTH ? { 'X-Shared-Link-Auth': SHARED_LINK_AUTH } : {}
  url = url + serializeQuery(query, extraQuery)
  return fetch(url, { signal: abortController.signal, headers: headers })
    .then(response => {
      if (!response.ok) {
        return response.json().then((payload) => {
          throw new ApiError(payload.error, payload)
        })
      }
      return response.json()
    })
}

export function put(url, body) {
  return fetch(url, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  })
}
