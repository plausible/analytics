import JsonURL from '@jsonurl/jsonurl'

export function apiPath(site, path = '') {
  return `/api/stats/${encodeURIComponent(site.domain)}${path}`
}

export function siteBasePath(site, path = '') {
  return `/${encodeURIComponent(site.domain)}${path}`
}

export function sitePath(site, path = '') {
  return siteBasePath(site, path) + window.location.search
}

export function setQuery(key, value) {
  const query = new PlausibleSearchParams(window.location.search)
  query.set(key, value)
  return `${window.location.pathname}?${query.toString()}`
}

export function externalLinkForPage(domain, page) {
  const domainURL = new URL(`https://${domain}`)
  return `https://${domainURL.host}${page}`
}

export function isValidHttpUrl(string) {
  let url;

  try {
    url = new URL(string);
  } catch (_) {
    return false;
  }

  return url.protocol === "http:" || url.protocol === "https:";
}


export function trimURL(url, maxLength) {
  if (url.length <= maxLength) {
    return url;
  }

  const ellipsis = "...";

  if (isValidHttpUrl(url)) {
    const [protocol, restURL] = url.split('://');
    const parts = restURL.split('/');

    const host = parts.shift();
    if (host.length > maxLength - 5) {
      return `${protocol}://${host.substr(0, maxLength - 5)}${ellipsis}${restURL.slice(-maxLength + 5)}`;
    }

    let remainingLength = maxLength - host.length - 5;
    let trimmedURL = `${protocol}://${host}`;

    for (const part of parts) {
      if (part.length <= remainingLength) {
        trimmedURL += '/' + part;
        remainingLength -= part.length + 1;
      } else {
        const startTrim = Math.floor((remainingLength - 3) / 2);
        const endTrim = Math.ceil((remainingLength - 3) / 2);
        trimmedURL += `/${part.substr(0, startTrim)}...${part.slice(-endTrim)}`;
        break;
      }
    }

    return trimmedURL;
  } else {
    const leftSideLength = Math.floor(maxLength / 2);
    const rightSideLength = maxLength - leftSideLength;

    const leftSide = url.slice(0, leftSideLength);
    const rightSide = url.slice(-rightSideLength);

    return leftSide + ellipsis + rightSide;
  }
}

export class PlausibleSearchParams extends URLSearchParams {
  set(key, value) {
    if (typeof value === 'object') {
      value = JsonURL.stringify(value)
      if (value.length > 2) {
        super.set(key, value)
      } else {
        super.delete(key)
      }
    } else {
      super.set(key, value)
    }
  }

  toString() {
    // Don't url-encode values that don't need urlencoding strictly and are used in JsonURL
    return super.toString().replaceAll("%28", "(").replaceAll("%29", ")").replaceAll("%2C", ",").replaceAll("%3A", ":")
  }
}
