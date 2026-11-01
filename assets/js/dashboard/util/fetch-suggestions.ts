import * as api from '../api'
import { DashboardState, Filter } from '../dashboard-state'
import { PlausibleSite } from '../site-context'
import { apiPath } from './url'
import {
  replaceFilterByPrefix,
  omitFiltersByKeyPrefix,
  EVENT_PROPS_PREFIX,
  FILTER_OPERATIONS,
  getPropertyKeyFromFilterKey,
  isFreeChoiceFilterOperation
} from './filters'

export type Suggestion = { value: string | number; label: string }

export type SuggestionsRequest = { path: string; additionalFilter?: Filter }

export function fetchSuggestions(
  path: string,
  dashboardState: DashboardState,
  input: string,
  additionalFilter?: Filter
): Promise<Suggestion[]> {
  const updatedQuery = queryForSuggestions(dashboardState, additionalFilter)
  return api.get(path, updatedQuery, { q: input.trim() })
}

export function getValueSuggestionsRequest(
  site: Pick<PlausibleSite, 'domain'>,
  [operation, filterKey]: Filter
): SuggestionsRequest | null {
  if (isFreeChoiceFilterOperation(operation)) {
    return null
  }
  if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return {
      path: apiPath(
        site,
        `/suggestions/custom-prop-values/${encodeURIComponent(propKey)}`
      ),
      additionalFilter: [FILTER_OPERATIONS.isNot, filterKey, ['(none)']]
    }
  }
  return {
    path: apiPath(site, `/suggestions/${filterKey}`),
    additionalFilter:
      filterKey === 'goal'
        ? undefined
        : [FILTER_OPERATIONS.isNot, filterKey, []]
  }
}

function queryForSuggestions(
  dashboardState: DashboardState,
  additionalFilter?: Filter
): DashboardState {
  let filters = dashboardState.filters
  if (additionalFilter) {
    const [_operation, filterKey, clauses] = additionalFilter

    // For suggestions, we remove already-applied filter with same key from dashboardState and add new filter (if feasible)
    if (clauses.length > 0) {
      filters = replaceFilterByPrefix(
        dashboardState,
        filterKey,
        additionalFilter
      )
    } else {
      filters = omitFiltersByKeyPrefix(dashboardState, filterKey)
    }
  }
  return { ...dashboardState, filters }
}
