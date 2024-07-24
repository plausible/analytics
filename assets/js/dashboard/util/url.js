import JsonURL from '@jsonurl/jsonurl'
import { parseSearchWith } from '@tanstack/react-router';

export function apiPath(site, path = '') {
  return `/api/stats/${encodeURIComponent(site.domain)}${path}/`
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

/** 
 * @param {String} input - value to encode for URI
 * @returns {String} value encoded for URI
 */
export function encodeURIComponentPermissive(input) {
  return encodeURIComponent(input)
  .replaceAll("%2C", ",")
  .replaceAll("%3A", ":")
  .replaceAll("%2F", "/")
}

export function encodeSearchParamEntries([k, v]) {
  return `${encodeURIComponentPermissive(k)}=${encodeURIComponentPermissive(v)}`
}

export function isSearchEntryDefined([_key, value]) {
  return value !== undefined
}

export function stringifySearch(searchRecord) {
    const definedSearchEntries = Object.entries(searchRecord || {}).map(stringifySearchEntry).filter(isSearchEntryDefined)

    const encodedSearchEntries = definedSearchEntries.map(encodeSearchParamEntries)
    
    return encodedSearchEntries.length ? `?${encodedSearchEntries.join('&')}` : ''
}

export function stringifySearchEntry([key, value]) {
  const isEmptyObjectOrArray = typeof value === 'object' && value !== null && Object.entries(value).length === 0;
  if (  value === undefined ||
    value === null ||
    isEmptyObjectOrArray
  ) {
    return [key, undefined]
  }
  
  return [key, JsonURL.stringify(value)]
}

export function parseSearchFragment(searchStringFragment) {
  const fragmentWithEncodedEquals = searchStringFragment.replaceAll('=','%3D');
  return JsonURL.parse(fragmentWithEncodedEquals)
}

export const parseSearch = parseSearchWith(parseSearchFragment)