/* @format */
import JsonURL from '@jsonurl/jsonurl'
import { PlausibleSite } from '../site-context'

export function apiPath(
  site: Pick<PlausibleSite, 'domain'>,
  path = ''
): string {
  return `/api/stats/${encodeURIComponent(site.domain)}${path}/`
}

export function externalLinkForPage(
  domain: PlausibleSite['domain'],
  page: string
): string {
  const domainURL = new URL(`https://${domain}`)
  return `https://${domainURL.host}${page}`
}

export function isValidHttpUrl(input: string): boolean {
  let url

  try {
    url = new URL(input)
  } catch (_) {
    return false
  }

  return url.protocol === 'http:' || url.protocol === 'https:'
}

export function trimURL(url: string, maxLength: number): string {
  if (url.length <= maxLength) {
    return url
  }

  const ellipsis = '...'

  if (isValidHttpUrl(url)) {
    const [protocol, restURL] = url.split('://')
    const parts = restURL.split('/')

    const host = parts.shift() || ''
    if (host.length > maxLength - 5) {
      return `${protocol}://${host.substr(0, maxLength - 5)}${ellipsis}${restURL.slice(-maxLength + 5)}`
    }

    let remainingLength = maxLength - host.length - 5
    let trimmedURL = `${protocol}://${host}`

    for (const part of parts) {
      if (part.length <= remainingLength) {
        trimmedURL += '/' + part
        remainingLength -= part.length + 1
      } else {
        const startTrim = Math.floor((remainingLength - 3) / 2)
        const endTrim = Math.ceil((remainingLength - 3) / 2)
        trimmedURL += `/${part.substr(0, startTrim)}...${part.slice(-endTrim)}`
        break
      }
    }

    return trimmedURL
  } else {
    const leftSideLength = Math.floor(maxLength / 2)
    const rightSideLength = maxLength - leftSideLength

    const leftSide = url.slice(0, leftSideLength)
    const rightSide = url.slice(-rightSideLength)

    return leftSide + ellipsis + rightSide
  }
}

export function encodeURIComponentPermissive(input: string): string {
  return (
    encodeURIComponent(input)
      /* @ts-expect-error API supposedly not present in compilation target */
      .replaceAll('%2C', ',')
      .replaceAll('%3A', ':')
      .replaceAll('%2F', '/')
  )
}

export function encodeSearchParamEntry([k, v]: [string, string]): string {
  return `${encodeURIComponentPermissive(k)}=${encodeURIComponentPermissive(v)}`
}

export function isSearchEntryDefined(
  entry: [string, undefined | string]
): entry is [string, string] {
  return entry[1] !== undefined
}

export function stringifySearch(
  searchRecord: Record<string, unknown>
): '' | string {
  const definedSearchEntries = Object.entries(searchRecord || {})
    .map(stringifySearchEntry)
    .filter(isSearchEntryDefined)

  const encodedSearchEntries = definedSearchEntries.map(encodeSearchParamEntry)

  return encodedSearchEntries.length ? `?${encodedSearchEntries.join('&')}` : ''
}

export function stringifySearchEntry([key, value]: [string, unknown]): [
  string,
  undefined | string
] {
  const isEmptyObjectOrArray =
    typeof value === 'object' &&
    value !== null &&
    Object.entries(value).length === 0
  if (value === undefined || value === null || isEmptyObjectOrArray) {
    return [key, undefined]
  }

  return [key, JsonURL.stringify(value)]
}

export function parseSearchFragment(
  searchStringFragment: string
): null | unknown {
  if (searchStringFragment === '') {
    return null
  }
  // tricky: the search string fragment is already decoded due to URLSearchParams intermediate (see tests),
  // and these symbols are unparseable
  const fragmentWithReEncodedSymbols = searchStringFragment
    /* @ts-expect-error API supposedly not present in compilation target */
    .replaceAll('=', encodeURIComponent('='))
    .replaceAll('#', encodeURIComponent('#'))
    .replaceAll('|', encodeURIComponent('|'))
    .replaceAll(' ', encodeURIComponent(' '))

  try {
    return JsonURL.parse(fragmentWithReEncodedSymbols)
  } catch (error) {
    console.error(
      `Failed to parse URL fragment ${fragmentWithReEncodedSymbols}`,
      error
    )
    return null
  }
}

export function parseSearch(searchString: string): Record<string, unknown> {
  const urlSearchParams = new URLSearchParams(searchString)
  const searchRecord: Record<string, unknown> = {}
  urlSearchParams.forEach((v, k) => (searchRecord[k] = parseSearchFragment(v)))
  return searchRecord
}

export function maybeEncodeRouteParam(param: string) {
  return param.includes('/') ? encodeURIComponent(param) : param
}
