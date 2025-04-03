import { Filter, FilterClauseLabels } from '../query'
import { v1 } from './url-search-params-v1'
import { v2 } from './url-search-params-v2'

/**
 * These charcters are not URL encoded to have more readable URLs.
 * Browsers seem to handle this just fine.
 * `?f=is,page,/my/page/:some_param` vs `?f=is,page,%2Fmy%2Fpage%2F%3Asome_param``
 */
const NOT_URL_ENCODED_CHARACTERS = ':/'

export const FILTER_URL_PARAM_NAME = 'f'

const LABEL_URL_PARAM_NAME = 'l'

const REDIRECTED_SEARCH_PARAM_NAME = 'r'

/**
 * This function is able to serialize for URL simple params @see serializeSimpleSearchEntry as well
 * two complex params, labels and filters.
 */
export function stringifySearch(
  searchRecord: Record<string, null | undefined | number | string | unknown>
): '' | string {
  const { filters, labels, ...rest } = searchRecord ?? {}
  const definedSearchEntries = Object.entries(rest)
    .map(serializeSimpleSearchEntry)
    .filter(isSearchEntryDefined)
    .map(([k, v]) => `${k}=${v}`)

  if (!Array.isArray(filters) || !filters.length) {
    return definedSearchEntries.length
      ? `?${definedSearchEntries.join('&')}`
      : ''
  }

  const serializedFilters = Array.isArray(filters)
    ? filters.map((f) => `${FILTER_URL_PARAM_NAME}=${serializeFilter(f)}`)
    : []

  const serializedLabels = Object.entries(labels ?? {}).map(
    (entry) => `${LABEL_URL_PARAM_NAME}=${serializeLabelsEntry(entry)}`
  )

  return `?${serializedFilters.concat(serializedLabels).concat(definedSearchEntries).join('&')}`
}

export function normalizeSearchString(searchString: string): string {
  return searchString.startsWith('?') ? searchString.slice(1) : searchString
}

export function parseSearch(searchString: string): Record<string, unknown> {
  const searchRecord: Record<string, string | boolean> = {}
  const filters: Filter[] = []
  const labels: FilterClauseLabels = {}

  const normalizedSearchString = normalizeSearchString(searchString)

  if (!normalizedSearchString.length) {
    return searchRecord
  }

  const meaningfulParams = normalizedSearchString
    .split('&')
    .filter((i) => i.length > 0)

  for (const param of meaningfulParams) {
    const [key, rawValue = ''] = param.split('=')
    switch (key) {
      case FILTER_URL_PARAM_NAME: {
        const filter = parseFilter(rawValue)
        if (filter.length === 3 && filter[2].length) {
          filters.push(filter)
        }
        break
      }
      case LABEL_URL_PARAM_NAME: {
        const [labelKey, labelValue] = parseLabelsEntry(rawValue)
        if (labelKey.length && labelValue.length) {
          labels[labelKey] = labelValue
        }
        break
      }
      case '': {
        break
      }
      default: {
        const parsedValue = parseSimpleSearchEntry(rawValue)
        if (parsedValue !== null) {
          searchRecord[decodeURIComponent(key)] = parsedValue
        }
      }
    }
  }

  return {
    ...searchRecord,
    ...(filters.length && { filters }),
    ...(Object.keys(labels).length && { labels })
  }
}

/**
 * Serializes and flattens @see FilterClauseLabels entries.
 * Examples:
 * ["US","United States"] -> "US,United%20States"
 * ["US-CA","California"] -> "US-CA,California"
 * ["5391959","San Francisco"] -> "5391959,San%20Francisco"
 */
export function serializeLabelsEntry([labelKey, labelValue]: [string, string]) {
  return `${encodeURIComponentPermissive(labelKey, NOT_URL_ENCODED_CHARACTERS)},${encodeURIComponentPermissive(labelValue, NOT_URL_ENCODED_CHARACTERS)}`
}

/**
 * Parses the output of @see serializeLabelsEntry back to labels object entry.
 */
export function parseLabelsEntry(
  labelKeyValueString: string
): [string, string] {
  const [key, value] = labelKeyValueString.split(',')
  return [decodeURIComponent(key), decodeURIComponent(value)]
}

/**
 * Serializes and flattens filters array item.
 * Examples:
 * ["is", "entry_page", ["/blog", "/news"]] -> "is,entry_page,/blog,/news"
 */
export function serializeFilter([operator, dimension, clauses]: Filter) {
  const serializedFilter = [
    encodeURIComponentPermissive(operator, NOT_URL_ENCODED_CHARACTERS),
    encodeURIComponentPermissive(dimension, NOT_URL_ENCODED_CHARACTERS),
    ...clauses.map((clause) =>
      encodeURIComponentPermissive(
        clause.toString(),
        NOT_URL_ENCODED_CHARACTERS
      )
    )
  ].join(',')
  return serializedFilter
}

/**
 * Parses the output of @see serializeFilter back to filters array item.
 */
export function parseFilter(filterString: string): Filter {
  const [operator, dimension, ...unparsedClauses] = filterString.split(',')
  return [
    decodeURIComponent(operator),
    decodeURIComponent(dimension),
    unparsedClauses.map(decodeURIComponent)
  ]
}

/**
 * Encodes for URL simple search param values.
 * Encodes numbers and number-like strings as indistinguishable strings. Parse treats them as strings.
 * Encodes booleans and strings "true" and "false" as indistinguishable strings. Parse treats these as booleans.
 * Unifies unhandleable complex search entries like undefined, null, objects and arrays as undefined.
 * Complex URL params must be handled separately.
 */
export function serializeSimpleSearchEntry([key, value]: [string, unknown]): [
  string,
  undefined | string
] {
  if (value === undefined || value === null || typeof value === 'object') {
    return [key, undefined]
  }
  return [
    encodeURIComponentPermissive(key, ',:/'),
    encodeURIComponentPermissive(value.toString(), ',:/')
  ]
}

/**
 * Parses output of @see serializeSimpleSearchEntry.
 */
export function parseSimpleSearchEntry(
  searchParamValue: string
): null | string | boolean {
  if (searchParamValue === 'true') {
    return true
  }
  if (searchParamValue === 'false') {
    return false
  }
  return decodeURIComponent(searchParamValue)
}

export function encodeURIComponentPermissive(
  input: string,
  permittedCharacters: string
): string {
  return Array.from(permittedCharacters)
    .map((character) => [encodeURIComponent(character), character])
    .reduce(
      (acc, [encodedCharacter, character]) =>
        /* @ts-expect-error API supposedly not present in compilation target, but works in major browsers */
        acc.replaceAll(encodedCharacter, character),
      encodeURIComponent(input)
    )
}

export function isSearchEntryDefined(
  entry: [string, undefined | string]
): entry is [string, string] {
  return entry[1] !== undefined
}

function isAlreadyRedirected(searchParams: URLSearchParams) {
  return ['v1', 'v2'].includes(searchParams.get(REDIRECTED_SEARCH_PARAM_NAME)!)
}

/** 
  Dashboard state is kept on the URL for people to be able to link to what that they see.
  Because dashboard state is a complex object, in the interest of readable URLs, custom serialization and parsing is in place.
  
  Versions
    * v1: @see v1
      A custom encoding schema was used for filters, (e.g. "?page=/blog"). 
      This was not flexible enough and diverged from how we represented filters in the code.
      
    * v2: @see v2
      jsonurl library was used to serialize the state. 
      The links from this solution didn't always auto-sense across all platforms (e.g. Twitter), cutting off too soon and leading users to broken dashboards.
      
    * current version: this module. 
      Custom encoding.
   
  The purpose of this function is to redirect users from one of the previous versions to the current version, 
  so previous dashboard links still work.
*/
export function getRedirectTarget(windowLocation: Location): null | string {
  const searchParams = new URLSearchParams(windowLocation.search)
  if (isAlreadyRedirected(searchParams)) {
    return null
  }
  const isCurrentVersion = searchParams.get(FILTER_URL_PARAM_NAME)
  if (isCurrentVersion) {
    return null
  }

  const isV2 = v2.isV2(searchParams)
  if (isV2) {
    return `${windowLocation.pathname}${stringifySearch({ ...v2.parseSearch(windowLocation.search), [REDIRECTED_SEARCH_PARAM_NAME]: 'v2' })}`
  }

  const searchRecord = v2.parseSearch(windowLocation.search)
  const isV1 = v1.isV1(searchRecord)

  if (!isV1) {
    return null
  }

  return `${windowLocation.pathname}${stringifySearch({ ...v1.parseSearchRecord(searchRecord), [REDIRECTED_SEARCH_PARAM_NAME]: 'v1' })}`
}

/** Called once before React app mounts. If legacy url search params are present, does a redirect to new format. */
export function redirectForLegacyParams(
  windowLocation: Location,
  windowHistory: History
) {
  const redirectTargetURL = getRedirectTarget(windowLocation)
  if (redirectTargetURL === null) {
    return
  }
  windowHistory.pushState({}, '', redirectTargetURL)
}
