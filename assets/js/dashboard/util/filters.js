import * as api from '../api'

export const FILTER_GROUPS = {
  'page': ['page', 'entry_page', 'exit_page'],
  'source': ['source', 'referrer'],
  'location': ['country', 'region', 'city'],
  'screen': ['screen'],
  'browser': ['browser', 'browser_version'],
  'os': ['os', 'os_version'],
  'utm': ['utm_medium', 'utm_source', 'utm_campaign', 'utm_term', 'utm_content'],
  'goal': ['goal'],
  'props': ['props'],
  'hostname': ['hostname']
}

export const FILTER_GROUP_TO_MODAL_TYPE = Object.fromEntries(
  Object.entries(FILTER_GROUPS)
    .flatMap(([modalName, filterGroups]) => filterGroups.map((filterGroup) => [filterGroup, modalName]))
)

export const NO_CONTAINS_OPERATOR = new Set(['goal', 'screen'].concat(FILTER_GROUPS['location']))

export const EVENT_PROPS_PREFIX = "props:"

export const FILTER_OPERATIONS = {
  isNot: 'is not',
  contains: 'contains',
  is: 'is'
};

export const OPERATION_PREFIX = {
  [FILTER_OPERATIONS.isNot]: '!',
  [FILTER_OPERATIONS.contains]: '~',
  [FILTER_OPERATIONS.is]: ''
};

export function supportsIsNot(filterName) {
  return !['goal', 'prop_key'].includes(filterName)
}

export function isFreeChoiceFilter(filterName) {
  return !NO_CONTAINS_OPERATOR.has(filterName)
}

// As of March 2023, Safari does not support negative lookbehind regexes. In case it throws an error, falls back to plain | matching. This means
// escaping pipe characters in filters does not currently work in Safari
let NON_ESCAPED_PIPE_REGEX;
try {
  NON_ESCAPED_PIPE_REGEX = new RegExp("(?<!\\\\)\\|", "g")
} catch (_e) {
  NON_ESCAPED_PIPE_REGEX = '|'
}

const ESCAPED_PIPE = '\\|'

export function escapeFilterValue(value) {
  return value.replaceAll(NON_ESCAPED_PIPE_REGEX, ESCAPED_PIPE)
}

function toFilterQuery(type, clauses) {
  const prefix = OPERATION_PREFIX[type];
  const result = clauses.map(clause => escapeFilterValue(clause.trim())).join('|')
  return prefix + result;
}

export function parsePrefix(rawValue) {
  const operation = Object.keys(OPERATION_PREFIX)
    .find(operation => OPERATION_PREFIX[operation] === rawValue[0]) || FILTER_OPERATIONS.is;

  const value = operation === FILTER_OPERATIONS.is ? rawValue : rawValue.substring(1)

  const values = value
    .split(NON_ESCAPED_PIPE_REGEX)
    .filter((clause) => !!clause)
    .map((val) => val.replaceAll(ESCAPED_PIPE, '|'))

  return { operation, values }
}

export function parseQueryPropsFilter(query) {
  return Object.entries(query.filters['props']).map(([key, propVal]) => {
    const { operation, values } = parsePrefix(propVal)
    const clauses = values.map(val => { return { value: val, label: val } })
    return { propKey: { label: key, value: key }, operation, clauses }
  })
}

export function getPropertyKeyFromFilterKey(filterKey) {
  return filterKey.slice(EVENT_PROPS_PREFIX.length)
}

export function getFiltersByKeyPrefix(query, prefix) {
  return query.filters.filter(([_query, filterKey, _clauses]) => filterKey.startsWith(prefix))
}

export function isFilteringOnFixedValue(query, filterKey, expectedValue) {
  const filters = query.filters.filter(([_operation, key]) => filterKey == key)
  if (filters.length == 1) {
    const [operation, _filterKey, clauses] = filters[0]
    return operation === FILTER_OPERATIONS.is && clauses.length === 1 && (!expectedValue || clauses[0] == expectedValue)
  }
  return false
}

export function formatFilterGroup(filterGroup) {
  if (filterGroup === 'utm') {
    return 'UTM tags'
  } else if (filterGroup === 'location') {
    return 'Location'
  } else if (filterGroup === 'props') {
    return 'Property'
  } else {
    return formattedFilters[filterGroup]
  }
}

export function cleanLabels(filters, labels, mergedFilterKey, mergedLabels) {
  const filteredBy = Object.fromEntries(
    filters
    .flatMap(([_operation, filterKey, clauses]) => ['country', 'region', 'city'].includes(filterKey) ? clauses : [])
    .map((value) => [value, true])
  )
  let result = { ...labels }
  for (const value in labels) {
    if (!filteredBy[value]) {
      delete result[value]
    }
  }

  if (mergedFilterKey && ['country', 'region', 'city'].includes(mergedFilterKey)) {
    result = {
      ...result,
      ...mergedLabels
    }
  }

  return result
}


// :TODO: New schema for filters in the BE
export function serializeApiFilters(filters) {
  const cleaned = {}
  filters.forEach(([operation, filterKey, clauses]) => {
    if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
      cleaned.props ||= {}
      cleaned.props[getPropertyKeyFromFilterKey(filterKey)] = toFilterQuery(operation, clauses)
    } else {
      cleaned[filterKey] = toFilterQuery(operation, clauses)
    }
  })
  return JSON.stringify(cleaned)
}

export function fetchSuggestions(apiPath, query, input, additionalFilter) {
  const updatedQuery = queryForSuggestions(query, additionalFilter)
  return api.get(apiPath, updatedQuery, { q: input.trim() })
}

function queryForSuggestions(query, additionalFilter) {
  let filters = query.filters
  if (additionalFilter && additionalFilter[2].length > 0) {
    filters = filters.concat([additionalFilter])
  }
  return { ...query, filters }
}

export function filterType([_operation, filterKey, _clauses]) {
  return filterKey.startsWith(EVENT_PROPS_PREFIX) ? 'props' : filterKey
}


export const formattedFilters = {
  'goal': 'Goal',
  'props': 'Property',
  'prop_key': 'Property',
  'prop_value': 'Value',
  'source': 'Source',
  'utm_medium': 'UTM Medium',
  'utm_source': 'UTM Source',
  'utm_campaign': 'UTM Campaign',
  'utm_content': 'UTM Content',
  'utm_term': 'UTM Term',
  'referrer': 'Referrer URL',
  'screen': 'Screen size',
  'browser': 'Browser',
  'browser_version': 'Browser Version',
  'os': 'Operating System',
  'os_version': 'Operating System Version',
  'country': 'Country',
  'region': 'Region',
  'city': 'City',
  'page': 'Page',
  'hostname': 'Hostname',
  'entry_page': 'Entry Page',
  'exit_page': 'Exit Page',
}
