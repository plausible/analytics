import {formatISO} from './date'

function serialize(obj) {
  var str = [];
  for (var p in obj)
    if (obj.hasOwnProperty(p)) {
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
    }
  return str.join("&");
}

export function serializeQuery(query, ...extraQuery) {
  query = Object.assign({}, query, {
    date: query.date ? formatISO(query.date) : undefined,
    filters: query.filters ? JSON.stringify(query.filters) : undefined
  }, ...extraQuery)

  return '?' + serialize(query)
}

export function get(url, query, ...extraQuery) {
  url = url + serializeQuery(query, extraQuery)
  return fetch(url).then(res => res.json())
}
