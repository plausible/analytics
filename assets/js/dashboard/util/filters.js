/** @format */

import React, { useMemo } from 'react'
import * as api from '../api'
import { useQueryContext } from '../query-context'
import {
  formatSegmentIdAsLabelKey,
  isSegmentFilter
} from '../segments/segments'

export const FILTER_MODAL_TO_FILTER_GROUP = {
  page: ['page', 'entry_page', 'exit_page'],
  source: ['source', 'channel', 'referrer'],
  location: ['country', 'region', 'city'],
  screen: ['screen'],
  browser: ['browser', 'browser_version'],
  os: ['os', 'os_version'],
  utm: ['utm_medium', 'utm_source', 'utm_campaign', 'utm_term', 'utm_content'],
  goal: ['goal'],
  props: ['props'],
  hostname: ['hostname'],
  segment: ['segment']
}

export const FILTER_GROUP_TO_MODAL_TYPE = Object.fromEntries(
  Object.entries(FILTER_MODAL_TO_FILTER_GROUP).flatMap(
    ([modalName, filterGroups]) =>
      filterGroups.map((filterGroup) => [filterGroup, modalName])
  )
)

export const EVENT_PROPS_PREFIX = 'props:'

export const FILTER_OPERATIONS = {
  is: 'is',
  isNot: 'is_not',
  contains: 'contains',
  contains_not: 'contains_not'
}

export const FILTER_OPERATIONS_DISPLAY_NAMES = {
  [FILTER_OPERATIONS.is]: 'is',
  [FILTER_OPERATIONS.isNot]: 'is not',
  [FILTER_OPERATIONS.contains]: 'contains',
  [FILTER_OPERATIONS.contains_not]: 'does not contain'
}

const OPERATION_PREFIX = {
  [FILTER_OPERATIONS.isNot]: '!',
  [FILTER_OPERATIONS.contains]: '~',
  [FILTER_OPERATIONS.is]: ''
}

export function supportsIsNot(filterName) {
  return !['goal', 'prop_key'].includes(filterName)
}

export function supportsContains(filterName) {
  return !['screen']
    .concat(FILTER_MODAL_TO_FILTER_GROUP['location'])
    .includes(filterName)
}

export function isFreeChoiceFilterOperation(operation) {
  return [FILTER_OPERATIONS.contains, FILTER_OPERATIONS.contains_not].includes(
    operation
  )
}

// As of March 2023, Safari does not support negative lookbehind regexes. In case it throws an error, falls back to plain | matching. This means
// escaping pipe characters in filters does not currently work in Safari
let NON_ESCAPED_PIPE_REGEX
try {
  NON_ESCAPED_PIPE_REGEX = new RegExp('(?<!\\\\)\\|', 'g')
} catch (_e) {
  NON_ESCAPED_PIPE_REGEX = '|'
}

const ESCAPED_PIPE = '\\|'

export function getLabel(labels, filterKey, value) {
  if (['country', 'region', 'city'].includes(filterKey)) {
    return labels[value]
  }

  if (isSegmentFilter(['is', filterKey, []])) {
    return labels[formatSegmentIdAsLabelKey(value)]
  }

  return value
}

export function getPropertyKeyFromFilterKey(filterKey) {
  return filterKey.slice(EVENT_PROPS_PREFIX.length)
}

export function getFiltersByKeyPrefix(query, prefix) {
  return query.filters.filter(([_operation, filterKey, _clauses]) =>
    filterKey.startsWith(prefix)
  )
}

function omitFiltersByKeyPrefix(query, prefix) {
  return query.filters.filter(
    ([_operation, filterKey, _clauses]) => !filterKey.startsWith(prefix)
  )
}

export function replaceFilterByPrefix(query, prefix, filter) {
  return omitFiltersByKeyPrefix(query, prefix).concat([filter])
}

export function isFilteringOnFixedValue(query, filterKey, expectedValue) {
  const filters = query.filters.filter(([_operation, key]) => filterKey == key)
  if (filters.length == 1) {
    const [operation, _filterKey, clauses] = filters[0]
    return (
      operation === FILTER_OPERATIONS.is &&
      clauses.length === 1 &&
      (!expectedValue || clauses[0] == expectedValue)
    )
  }
  return false
}

export function hasGoalFilter(query) {
  return getFiltersByKeyPrefix(query, 'goal').length > 0
}

export function useHasGoalFilter() {
  const {
    query: { filters }
  } = useQueryContext()
  return useMemo(
    () => getFiltersByKeyPrefix({ filters }, 'goal').length > 0,
    [filters]
  )
}

export function isRealTimeDashboard(query) {
  return query?.period === 'realtime'
}

export function useIsRealtimeDashboard() {
  const {
    query: { period }
  } = useQueryContext()
  return useMemo(() => isRealTimeDashboard({ period }), [period])
}

export function plainFilterText(query, [operation, filterKey, clauses]) {
  const formattedFilter = formattedFilters[filterKey]

  if (formattedFilter) {
    return `${formattedFilter} ${FILTER_OPERATIONS_DISPLAY_NAMES[operation]} ${clauses.map((value) => getLabel(query.labels, filterKey, value)).reduce((prev, curr) => `${prev} or ${curr}`)}`
  } else if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return `Property ${propKey} ${FILTER_OPERATIONS_DISPLAY_NAMES[operation]} ${clauses.reduce((prev, curr) => `${prev} or ${curr}`)}`
  }

  throw new Error(`Unknown filter: ${filterKey}`)
}

export function styledFilterText(query, [operation, filterKey, clauses]) {
  const formattedFilter = formattedFilters[filterKey]

  if (formattedFilter) {
    return (
      <>
        {formattedFilter} {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}{' '}
        {clauses
          .map((value) => (
            <b key={value}>{getLabel(query.labels, filterKey, value)}</b>
          ))
          .reduce((prev, curr) => [prev, ' or ', curr])}{' '}
      </>
    )
  } else if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return (
      <>
        Property <b>{propKey}</b> {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}{' '}
        {clauses
          .map((label) => <b key={label}>{label}</b>)
          .reduce((prev, curr) => [prev, ' or ', curr])}{' '}
      </>
    )
  }

  throw new Error(`Unknown filter: ${filterKey}`)
}

// Note: Currently only a single goal filter can be applied at a time.
export function getGoalFilter(query) {
  return getFiltersByKeyPrefix(query, 'goal')[0] || null
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
      .flatMap(([_operation, filterKey, clauses]) => {
        if (filterKey === 'segment') {
          return clauses.map(formatSegmentIdAsLabelKey)
        }
        if (['country', 'region', 'city'].includes(filterKey)) {
          return clauses
        }
        return []
      })
      .map((value) => [value, true])
  )

  let result = { ...labels }
  for (const value in labels) {
    if (!filteredBy[value]) {
      delete result[value]
    }
  }

  if (
    mergedFilterKey &&
    ['country', 'region', 'city', 'segment'].includes(mergedFilterKey)
  ) {
    result = {
      ...result,
      ...mergedLabels
    }
  }

  return result
}

const NO_PREFIX_KEYS = new Set(['segment'])
const EVENT_FILTER_KEYS = new Set(['name', 'page', 'goal', 'hostname'])
const EVENT_PREFIX = 'event:'
const VISIT_PREFIX = 'visit:'

function remapFilterKey(filterKey) {
  if (NO_PREFIX_KEYS.has(filterKey)) {
    return filterKey
  }
  if (EVENT_FILTER_KEYS.has(filterKey)) {
    return `${EVENT_PREFIX}${filterKey}`
  }
  return `${VISIT_PREFIX}${filterKey}`
}

function remapApiFilterKey(apiFilterKey) {
  const isNoPrefixKey = NO_PREFIX_KEYS.has(apiFilterKey)

  if (isNoPrefixKey) {
    return apiFilterKey
  }

  const isEventKey = apiFilterKey.startsWith(EVENT_PREFIX)
  const isVisitKey = apiFilterKey.startsWith(VISIT_PREFIX)

  if (isEventKey) {
    return apiFilterKey.substring(EVENT_PREFIX.length)
  }
  if (isVisitKey) {
    return apiFilterKey.substring(VISIT_PREFIX.length)
  }

  return apiFilterKey // maybe throw?
}

export function remapToApiFilters(filters) {
  return filters.map(([operation, filterKey, clauses]) => {
    return [operation, remapFilterKey(filterKey), clauses]
  })
}

export function remapFromApiFilters(apiFilters) {
  return apiFilters.map(([operation, apiFilterKey, clauses]) => {
    return [operation, remapApiFilterKey(apiFilterKey), clauses]
  })
}

export function serializeApiFilters(filters) {
  return JSON.stringify(remapToApiFilters(filters))
}

export function fetchSuggestions(apiPath, query, input, additionalFilter) {
  const updatedQuery = queryForSuggestions(query, additionalFilter)
  return api.get(apiPath, updatedQuery, { q: input.trim() })
}

function queryForSuggestions(query, additionalFilter) {
  let filters = query.filters
  if (additionalFilter) {
    const [_operation, filterKey, clauses] = additionalFilter

    // For suggestions, we remove already-applied filter with same key from query and add new filter (if feasible)
    if (clauses.length > 0) {
      filters = replaceFilterByPrefix(query, filterKey, additionalFilter)
    } else {
      filters = omitFiltersByKeyPrefix(query, filterKey)
    }
  }
  return { ...query, filters }
}

export function getFilterGroup([_operation, filterKey, _clauses]) {
  return filterKey.startsWith(EVENT_PROPS_PREFIX) ? 'props' : filterKey
}

export const formattedFilters = {
  goal: 'Goal',
  props: 'Property',
  prop_key: 'Property',
  prop_value: 'Value',
  source: 'Source',
  channel: 'Channel',
  utm_medium: 'UTM Medium',
  utm_source: 'UTM Source',
  utm_campaign: 'UTM Campaign',
  utm_content: 'UTM Content',
  utm_term: 'UTM Term',
  referrer: 'Referrer URL',
  screen: 'Screen size',
  browser: 'Browser',
  browser_version: 'Browser Version',
  os: 'Operating System',
  os_version: 'Operating System Version',
  country: 'Country',
  region: 'Region',
  city: 'City',
  page: 'Page',
  hostname: 'Hostname',
  entry_page: 'Entry Page',
  exit_page: 'Exit Page',
  segment: 'Segment'
}

export function parseLegacyFilter(filterKey, rawValue) {
  const operation =
    Object.keys(OPERATION_PREFIX).find(
      (operation) => OPERATION_PREFIX[operation] === rawValue[0]
    ) || FILTER_OPERATIONS.is

  const value =
    operation === FILTER_OPERATIONS.is ? rawValue : rawValue.substring(1)

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
