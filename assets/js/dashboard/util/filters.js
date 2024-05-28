import * as api from '../api'

export const FILTER_MODAL_TO_FILTER_GROUP = {
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
  Object.entries(FILTER_MODAL_TO_FILTER_GROUP)
    .flatMap(([modalName, filterGroups]) => filterGroups.map((filterGroup) => [filterGroup, modalName]))
)

export const NO_CONTAINS_OPERATOR = new Set(['goal', 'screen'].concat(FILTER_MODAL_TO_FILTER_GROUP['location']))

export const EVENT_PROPS_PREFIX = "props:"

export const FILTER_OPERATIONS = {
  isNot: 'is_not',
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

function escapeFilterValue(value) {
  return value.replaceAll(NON_ESCAPED_PIPE_REGEX, ESCAPED_PIPE)
}

function toFilterQuery(type, clauses) {
  const prefix = OPERATION_PREFIX[type];
  const result = clauses.map(clause => escapeFilterValue(clause.toString().trim())).join('|')
  return prefix + result;
}


export function getLabel(labels, filterKey, value) {
  if (['country', 'region', 'city'].includes(filterKey)) {
    return labels[value]
  } else {
    return value
  }
}

export function getPropertyKeyFromFilterKey(filterKey) {
  return filterKey.slice(EVENT_PROPS_PREFIX.length)
}

export function getFiltersByKeyPrefix(query, prefix) {
  return query.filters.filter(([_operation, filterKey, _clauses]) => filterKey.startsWith(prefix))
}

function omitFiltersByKeyPrefix(query, prefix) {
  return query.filters.filter(([_operation, filterKey, _clauses]) => !filterKey.startsWith(prefix))
}

export function replaceFilterByPrefix(query, prefix, filter) {
  return omitFiltersByKeyPrefix(query, prefix).concat([filter])
}

export function isFilteringOnFixedValue(query, filterKey, expectedValue) {
  const filters = query.filters.filter(([_operation, key]) => filterKey == key)
  if (filters.length == 1) {
    const [operation, _filterKey, clauses] = filters[0]
    return operation === FILTER_OPERATIONS.is && clauses.length === 1 && (!expectedValue || clauses[0] == expectedValue)
  }
  return false
}

export function hasGoalFilter(query) {
  return getFiltersByKeyPrefix(query, "goal").length > 0
}

// Note: Currently only a single goal filter can be applied at a time.
export function getGoalFilter(query) {
  return getFiltersByKeyPrefix(query, "goal")[0] || null
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
    .flatMap(([_operation, filterKey, clauses]) => ['country', 'region', 'city'].includes(filterKey) ? clauses : []) // TODO
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

export function getFilterGroup([_operation, filterKey, _clauses]) {
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


export function parseLegacyFilter(filterKey, rawValue) {
  const operation = Object.keys(OPERATION_PREFIX)
    .find(operation => OPERATION_PREFIX[operation] === rawValue[0]) || FILTER_OPERATIONS.is;

  const value = operation === FILTER_OPERATIONS.is ? rawValue : rawValue.substring(1)

  const clauses = value
    .split(NON_ESCAPED_PIPE_REGEX)
    .filter((clause) => !!clause)
    .map((val) => val.replaceAll(ESCAPED_PIPE, '|'))

  return [operation, filterKey, clauses]
}

export function parseLegacyPropsFilter(rawValue) {
  return Object.entries(JSON.parse(rawValue)).map(([key, propVal]) => {
    return parseLegacyFilter(`${EVENT_PROPS_PREFIX}${key}`, propVal)
  })
}

export class Filter {
  constructor([operation, key, clauses]) {
    this.operation = operation
    this.key = key
    this.clauses = clauses
  }

  isPropFilter() {
    return this.key.startsWith(EVENT_PROPS_PREFIX)
  }

  getPropKey() {
    return this.key.slice(EVENT_PROPS_PREFIX.length)
  }

  displayName() {
    if (this.isPropFilter()) {
      return 'Property'
    } else {
      return formattedFilters[this.key]
    }
  }

  modalGroup() {
    if (this.isPropFilter()) {
      return 'props'
    } else {
      return FILTER_GROUP_TO_MODAL_TYPE[this.key]
    }
  }

  getGroup() {
    return this.isPropFilter() ? 'props' : this.key
  }

  isFreeChoice() {
    return !NO_CONTAINS_OPERATOR.has(this.key)
  }

  updateClauses(clauses) {
    return new this.constructor(this.operation, this.key, clauses)
  }

  updateOperation(newOperation) {
    return new this.constructor(newOperation, this.key, this.clauses)
  }
}
