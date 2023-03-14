export const FILTER_GROUPS = {
  'page': ['page', 'entry_page', 'exit_page'],
  'source': ['source', 'referrer'],
  'location': ['country', 'region', 'city'],
  'screen': ['screen'],
  'browser': ['browser', 'browser_version'],
  'os': ['os', 'os_version'],
  'utm': ['utm_medium', 'utm_source', 'utm_campaign', 'utm_term', 'utm_content'],
  'goal': ['goal'],
  'props': ['prop_key', 'prop_value']
}

export const FILTER_TYPES = {
  isNot: 'is not',
  contains: 'contains',
  is: 'is'
};

export const FILTER_PREFIXES = {
  [FILTER_TYPES.isNot]: '!',
  [FILTER_TYPES.contains]: '~',
  [FILTER_TYPES.is]: ''
};

function parsePrefix(rawValue) {
  const type = Object.keys(FILTER_PREFIXES)
    .find(type => FILTER_PREFIXES[type] === rawValue[0]) || FILTER_TYPES.is;

  const value = [FILTER_TYPES.isNot, FILTER_TYPES.contains].includes(type)
    ? rawValue.substring(1)
    : rawValue;

  const values = value
    .split('|')
    .filter((clause) => !!clause)

  return {type, values}
}

export function parseQueryFilter(query, filter) {
  if (filter === 'props') {
    const rawValue = query.filters['props']
    const [[_propKey, propVal]] = Object.entries(rawValue)
    const {type, values} = parsePrefix(propVal)
    const clauses = values.map(val => { return {value: val, label: val}})
    return {type, clauses}
  } else {
    const {type, values} = parsePrefix(query.filters[filter] || '')

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

    const clauses = values.map((value, index) => { return {value, label: labels[index]}})

    return {type, clauses}
  }
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
  'entry_page': 'Entry Page',
  'exit_page': 'Exit Page'
}
