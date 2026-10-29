import { DashboardState, Filter } from '../dashboard-state'
import {
  EVENT_PROPS_PREFIX,
  FILTER_OPERATIONS_DISPLAY_NAMES,
  formattedFilters,
  getLabel,
  getPropertyKeyFromFilterKey
} from './filters'

/** e.g. { dimension: 'Country', operation: 'is', values: ['Germany', 'Poland'] } */
export function getFilterTextParts(
  dashboardState: Pick<DashboardState, 'labels'>,
  [operation, filterKey, clauses]: Filter
) {
  return {
    dimension: getDimensionName(filterKey),
    operation: FILTER_OPERATIONS_DISPLAY_NAMES[operation],
    values: clauses.map((value) =>
      getLabel(dashboardState.labels, filterKey, value)
    )
  }
}

/** e.g. 'Country is Germany or Poland' */
export function plainFilterText(
  dashboardState: Pick<DashboardState, 'labels'>,
  filter: Filter
) {
  const { dimension, operation, values } = getFilterTextParts(
    dashboardState,
    filter
  )
  return [dimension, operation, values.join(' or ')].filter(Boolean).join(' ')
}

function getDimensionName(filterKey: string): string {
  if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    return `Property '${getPropertyKeyFromFilterKey(filterKey)}'`
  }
  const formattedFilter = (
    formattedFilters as Record<string, string | undefined>
  )[filterKey]
  if (!formattedFilter) {
    throw new Error(`Unknown filter: ${filterKey}`)
  }
  return capitalize(formattedFilter)
}

function capitalize(str: string): string {
  return str[0].toUpperCase() + str.slice(1)
}
