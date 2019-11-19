import {formatISO} from './date'

function serialize(obj) {
  var str = [];
  for (var p in obj)
    if (obj.hasOwnProperty(p)) {
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
    }
  return str.join("&");
}

export function get(url, query, ...extraQuery) {
  query = Object.assign({}, query, {
    date: query.date ? formatISO(query.date) : undefined
  }, ...extraQuery)

  url = url + `?${serialize(query)}`
  return fetch(url).then(res => res.json())
}
