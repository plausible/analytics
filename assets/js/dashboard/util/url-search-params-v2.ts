import JsonURL from '@jsonurl/jsonurl'
import {
  encodeURIComponentPermissive,
  isSearchEntryDefined
} from './url-search-params'

const permittedCharactersInURLParamKeyValue = ',:/'

function isV2(urlSearchParams: URLSearchParams): boolean {
  return !!urlSearchParams.get('filters')
}

function encodeSearchParamEntry([k, v]: [string, string]): string {
  return [k, v]
    .map((s) =>
      encodeURIComponentPermissive(s, permittedCharactersInURLParamKeyValue)
    )
    .join('=')
}

function stringifySearch(searchRecord: Record<string, unknown>): '' | string {
  const definedSearchEntries = Object.entries(searchRecord || {})
    .map(stringifySearchEntry)
    .filter(isSearchEntryDefined)

  const encodedSearchEntries = definedSearchEntries.map(encodeSearchParamEntry)

  return encodedSearchEntries.length ? `?${encodedSearchEntries.join('&')}` : ''
}

function stringifySearchEntry([key, value]: [string, unknown]): [
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

function parseSearchFragment(searchStringFragment: string): null | unknown {
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

function parseSearch(searchString: string): Record<string, unknown> {
  const urlSearchParams = new URLSearchParams(searchString)
  const searchRecord: Record<string, unknown> = {}
  urlSearchParams.forEach((v, k) => (searchRecord[k] = parseSearchFragment(v)))
  return searchRecord
}

export const v2 = {
  isV2,
  parseSearch,
  parseSearchFragment,
  stringifySearch,
  stringifySearchEntry
}
