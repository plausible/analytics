import { DashboardState, Filter } from '../dashboard-state'
import { EVENT_PROPS_PREFIX, FILTER_OPERATIONS } from './filters'

// As of March 2023, Safari does not support negative lookbehind regexes. In case it throws an error, falls back to plain | matching. This means
// escaping pipe characters in filters does not currently work in Safari
let NON_ESCAPED_PIPE_REGEX: string | RegExp
try {
  NON_ESCAPED_PIPE_REGEX = new RegExp('(?<!\\\\)\\|', 'g')
} catch (_e) {
  NON_ESCAPED_PIPE_REGEX = '|'
}

const ESCAPED_PIPE = '\\|'
const OPERATION_PREFIX = {
  [FILTER_OPERATIONS.isNot]: '!',
  [FILTER_OPERATIONS.contains]: '~',
  [FILTER_OPERATIONS.is]: ''
}

const LEGACY_URL_PARAMETERS = {
  goal: null,
  source: null,
  utm_medium: null,
  utm_source: null,
  utm_campaign: null,
  utm_content: null,
  utm_term: null,
  referrer: null,
  screen: null,
  browser: null,
  browser_version: null,
  os: null,
  os_version: null,
  country: 'country_labels',
  region: 'region_labels',
  city: 'city_labels',
  page: null,
  hostname: null,
  entry_page: null,
  exit_page: null
}

function isV1(searchParams: URLSearchParams): boolean {
  for (const k of searchParams.keys()) {
    if (k === 'props' || LEGACY_URL_PARAMETERS.hasOwnProperty(k)) {
      return true
    }
  }
  return false
}

function parseSearch(searchString: string): Record<string, unknown> {
  const searchParams = new URLSearchParams(searchString)
  const updatedSearchRecordEntries = []
  const filters: Filter[] = []
  let labels: DashboardState['labels'] = {}

  for (const [key, value] of searchParams.entries()) {
    if (LEGACY_URL_PARAMETERS.hasOwnProperty(key)) {
      if (typeof value !== 'string') {
        continue
      }
      const filter = parseLegacyFilter(key, value) as Filter
      filters.push(filter)
      const labelsKey: string | null | undefined =
        LEGACY_URL_PARAMETERS[key as keyof typeof LEGACY_URL_PARAMETERS]
      const labelsParamValue = labelsKey ? searchParams.get(labelsKey) : null
      if (labelsParamValue) {
        const clauses = filter[2]
        const labelsValues = labelsParamValue
          .split('|')
          .filter((label) => !!label)
        const newLabels = Object.fromEntries(
          clauses.map((clause, index) => [clause, labelsValues[index]])
        )

        labels = Object.assign(labels, newLabels)
      }
    } else {
      updatedSearchRecordEntries.push([key, value])
    }
  }

  const propsParamValue = searchParams.get('props')
  if (typeof propsParamValue === 'string') {
    filters.push(...(parseLegacyPropsFilter(propsParamValue) as Filter[]))
  }
  updatedSearchRecordEntries.push(['filters', filters], ['labels', labels])
  return Object.fromEntries(updatedSearchRecordEntries)
}

function parseLegacyFilter(filterKey: string, rawValue: string): null | Filter {
  const operation =
    Object.keys(OPERATION_PREFIX).find(
      (operation) => OPERATION_PREFIX[operation] === rawValue[0]
    ) || FILTER_OPERATIONS.is

  const value =
    operation === FILTER_OPERATIONS.is ? rawValue : rawValue.substring(1)

  const clauses = value
    .split(NON_ESCAPED_PIPE_REGEX)
    .filter((clause) => !!clause)
    // @ts-expect-error API supposedly not present in compilation target, but works anyway
    .map((val) => val.replaceAll(ESCAPED_PIPE, '|'))

  return [operation, filterKey, clauses]
}

function parseLegacyPropsFilter(rawValue: string) {
  return Object.entries(JSON.parse(rawValue)).flatMap(([key, propVal]) =>
    typeof propVal === 'string'
      ? [parseLegacyFilter(`${EVENT_PROPS_PREFIX}${key}`, propVal)]
      : []
  )
}

export const v1 = {
  isV1,
  parseSearch
}
