export function apiPath(site, path = '') {
  return `/api/stats/${encodeURIComponent(site.domain)}${path}`
}

export function sitePath(site, path = '') {
  return `/${encodeURIComponent(site.domain)}${path}`
}
