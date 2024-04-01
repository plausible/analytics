export const FILTER_GROUPS = {
  'page': ['page', 'entry_page', 'exit_page'],
  'source': ['source', 'referrer'],
  'location': ['country', 'region', 'city'],
  'screen': ['screen'],
  'browser': ['browser', 'browser_version'],
  'os': ['os', 'os_version'],
  'utm': ['utm_medium', 'utm_source', 'utm_campaign', 'utm_term', 'utm_content'],
  'goal': ['goal'],
  'props': ['prop_key', 'prop_value'],
  'hostname': ['hostname'],
}

export const NO_CONTAINS_OPERATOR = new Set(['goal', 'screen'].concat(FILTER_GROUPS['location']))

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
  const result = clauses.map(clause => escapeFilterValue(clause.value.trim())).join('|')
  return prefix + result;
}

export function parsePrefix(rawValue) {
  const type = Object.keys(OPERATION_PREFIX)
    .find(type => OPERATION_PREFIX[type] === rawValue[0]) || FILTER_OPERATIONS.is;

  const value = type === FILTER_OPERATIONS.is ? rawValue : rawValue.substring(1)

  const values = value
    .split(NON_ESCAPED_PIPE_REGEX)
    .filter((clause) => !!clause)
    .map((val) => val.replaceAll(ESCAPED_PIPE, '|'))

  return { type, values }
}

export function parseQueryPropsFilter(query) {
  return Object.entries(query.filters['props']).map(([key, propVal]) => {
    const { type, values } = parsePrefix(propVal)
    const clauses = values.map(val => { return { value: val, label: val } })
    return { propKey: { label: key, value: key }, type, clauses }
  })
}

export function parseQueryFilter(query, filter) {
  const { type, values } = parsePrefix(query.filters[filter] || '')

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

  return { type, clauses }
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
  'exit_page': 'Exit Page'
}
