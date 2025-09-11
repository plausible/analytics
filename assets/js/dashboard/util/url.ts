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
): string | null {
  try {
    const domainURL = new URL(`https://${domain}`)
    return `https://${domainURL.host}${page}`
  } catch (_error) {
    return null
  }
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

export function maybeEncodeRouteParam(param: string) {
  return param.includes('/') ? encodeURIComponent(param) : param
}
