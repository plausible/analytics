import {formatISO} from './date'

let abortController = new AbortController()
let SHARED_LINK_AUTH = null

function serialize(obj) {
  var str = [];
  for (var p in obj)
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

function serializeFilters(filters) {
  const cleaned = {}
  Object.entries(filters).forEach(([key, val]) => val ? cleaned[key] = val : null);
  return JSON.stringify(cleaned)
}

export function serializeQuery(query, extraQuery=[]) {
  const queryObj = {}
  if (query.period)  { queryObj.period = query.period  }
  if (query.date)    { queryObj.date = formatISO(query.date)  }
  if (query.from)    { queryObj.from = formatISO(query.from)  }
  if (query.to)      { queryObj.to = formatISO(query.to)  }
  if (query.filters) { queryObj.filters = serializeFilters(query.filters)  }
  Object.assign(queryObj, ...extraQuery)

  return '?' + serialize(queryObj)
}

export function get(url, query, ...extraQuery) {
  const headers = SHARED_LINK_AUTH ? {'X-Shared-Link-Auth': SHARED_LINK_AUTH} : {}
  url = url + serializeQuery(query, extraQuery)
  return fetch(url, {signal: abortController.signal, headers: headers})
    .then( response => {
      if (!response.ok) { throw response }
      return response.json()
    })
}
