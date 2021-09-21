export function apiPath(site, path = '') {
  return `/api/stats/${encodeURIComponent(site.domain)}${path}`
}

export function sitePath(site, path = '') {
  return `/${encodeURIComponent(site.domain)}${path}`
}

export function setQuery(key, value) {
  const query = new URLSearchParams(window.location.search)
  query.set(key, value)
  return window.location.pathname + '?' + query.toString();
}
