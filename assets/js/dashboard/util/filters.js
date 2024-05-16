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

export function toFilterQuery(type, clauses) {
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

export function parseQueryFilter(query, filter) {
  const { operation, values } = parsePrefix(query.filters[filter] || '')

  let labels = values

  if (filter === 'country' && values.length > 0) {
    const rawLabel = (new URLSearchParams(window.location.search)).get('country_labels') || ''
    labels = rawLabel.split('|').filter(label => !!label)
  }

  if (filter === 'region' && values.length > 0) {
    const rawLabel = (new URLSearchParams(window.location.search)).get('region_labels') || ''
    labels = rawLabel.split('|').filter(label => !!label)
  }

  if (filter === 'city' && values.length > 0) {
    const rawLabel = (new URLSearchParams(window.location.search)).get('city_labels') || ''
    labels = rawLabel.split('|').filter(label => !!label)
  }

  const clauses = values.map((value, index) => { return { value, label: labels[index] } })

  return { operation, clauses }
}

export function isFilteringOnFixedValue(query, filter) {
  const { type, clauses } = parseQueryFilter(query, filter)
  return type == FILTER_OPERATIONS.is && clauses.length == 1
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

export function filterGroupForFilter(filter) {
  const map = Object.entries(FILTER_GROUPS).reduce((filterToGroupMap, [group, filtersInGroup]) => {
    const filtersToAdd = {}
    filtersInGroup.forEach((filterInGroup) => {
      filtersToAdd[filterInGroup] = group
    })

    return { ...filterToGroupMap, ...filtersToAdd }
  }, {})


  return map[filter] || filter
}

export function cleanLabels(filters, labels, mergedFilterKey, mergedLabels) {
  let result = labels
  if (mergedFilterKey && ['country', 'region', 'city'].includes(mergedFilterKey)) {
    result = {
      ...result,
      [mergedFilterKey]: mergedLabels
    }
  }
  return result
}


// :TODO: New schema for filters in the BE
export function serializeApiFilters(filters) {
  const cleaned = {}
  filters.forEach(([operation, filterKey, clauses]) => {
    cleaned[filterKey] = toFilterQuery(operation, clauses)
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
