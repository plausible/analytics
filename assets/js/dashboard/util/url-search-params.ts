/** @format */
import { Filter, FilterClauseLabels } from '../query'

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

export function parseSearch(searchString: string): Record<string, unknown> {
  const urlSearchParams = new URLSearchParams(searchString)
  const searchRecord: Record<string, string | boolean> = {}
  const filters: Filter[] = []
  const labels: FilterClauseLabels = {}
  urlSearchParams.forEach((value, key) => {
    switch (key) {
      case FILTER_URL_PARAM_NAME: {
        const filter = parseFilter(value)
        if (filter.length === 3 && filter[2].length) {
          filters.push(filter)
        }
        break
      }
      case LABEL_URL_PARAM_NAME: {
        const [labelKey, labelValue] = parseLabelsEntry(value)
        if (labelKey.length && labelValue.length) {
          labels[labelKey] = labelValue
        }
        break
      }
      default: {
        const parsedValue = parseSimpleSearchEntry(value)
        if (parsedValue !== null) {
          searchRecord[key] = parsedValue
        }
      }
    }
  })
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
  return `${encodeURIComponentPermissive(labelKey, ':/')},${encodeURIComponentPermissive(labelValue, ':/')}`
}

/**
 * Parses the output of @see serializeLabelsEntry back to labels object entry,
 * once it has gone through URL decoding via new URLSearchParams(location.search).
 */
export function parseLabelsEntry(
  labelKeyValueString: string
): [string, string] {
  const [key, value] = labelKeyValueString.split(',')
  return [key, value]
}

/**
 * Serializes and flattens filters array item.
 * Examples:
 * ["is", "entry_page", ["/blog", "/news"]] -> "is,entry_page,/blog,/news"
 */
export function serializeFilter([operator, dimension, clauses]: Filter) {
  const serializedFilter = [
    operator,
    dimension,
    ...clauses.map((clause) =>
      encodeURIComponentPermissive(clause.toString(), ':/')
    )
  ].join(',')
  return serializedFilter
}

/**
 * Parses the output of @see serializeFilter back to filters array item,
 * once it has gone through URL decoding via new URLSearchParams(location.search).
 */
export function parseFilter(filterString: string): Filter {
  const [operator, dimension, ...unparsedClauses] = filterString.split(',')
  return [operator, dimension, unparsedClauses]
}

/**
 * Encodes for URL simple search param values.
 * Unifies unhandleable complex search entries like undefined, null, objects and arrays as undefined.
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
 * Parses output of @see serializeSimpleSearchEntry,
 * once it has gone through URL decoding via new URLSearchParams(location.search)
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
  return searchParamValue
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

export const FILTER_URL_PARAM_NAME = 'f'
const LABEL_URL_PARAM_NAME = 'l'
