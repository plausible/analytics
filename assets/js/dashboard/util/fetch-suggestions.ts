import * as api from '../api'
import { DashboardState, Filter } from '../dashboard-state'
import { replaceFilterByPrefix, omitFiltersByKeyPrefix } from './filters'

export function fetchSuggestions(
  apiPath: string,
  dashboardState: DashboardState,
  input: string,
  additionalFilter?: Filter
) {
  const updatedQuery = queryForSuggestions(dashboardState, additionalFilter)
  return api.get(apiPath, updatedQuery, { q: input.trim() })
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
