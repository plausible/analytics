import React, { ReactNode, isValidElement, Fragment } from 'react'
import { DashboardState, Filter } from '../dashboard-state'
import {
  EVENT_PROPS_PREFIX,
  FILTER_OPERATIONS_DISPLAY_NAMES,
  formattedFilters,
  getLabel,
  getPropertyKeyFromFilterKey
} from './filters'

export function styledFilterText(
  dashboardState: Pick<DashboardState, 'labels'>,
  [operation, filterKey, clauses]: Filter
) {
  if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return (
      <>
        Property <b>{propKey}</b> {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}{' '}
        {formatClauses(clauses)}
      </>
    )
  }

  const formattedFilter = (
    formattedFilters as Record<string, string | undefined>
  )[filterKey]
  const clausesLabels = clauses.map((value) =>
    getLabel(dashboardState.labels, filterKey, value)
  )

  if (!formattedFilter) {
    throw new Error(`Unknown filter: ${filterKey}`)
  }

  return (
    <>
      {capitalize(formattedFilter)} {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}{' '}
      {formatClauses(clausesLabels)}
    </>
  )
}

export function plainFilterText(
  dashboardState: Pick<DashboardState, 'labels'>,
  filter: Filter
) {
  return reactNodeToString(styledFilterText(dashboardState, filter))
}

function formatClauses(labels: Array<string | number>): ReactNode[] {
  return labels.map((label, index) => (
    <Fragment key={index}>
      {index > 0 && ' or '}
      <b>{label}</b>
    </Fragment>
  ))
}

function capitalize(str: string): string {
  return str[0].toUpperCase() + str.slice(1)
}

function reactNodeToString(reactNode: ReactNode): string {
  let string = ''
  if (typeof reactNode === 'string') {
    string = reactNode
  } else if (typeof reactNode === 'number') {
    string = reactNode.toString()
  } else if (reactNode instanceof Array) {
    reactNode.forEach(function (child) {
      string += reactNodeToString(child)
    })
  } else if (isValidElement(reactNode)) {
    string += reactNodeToString(reactNode.props.children)
  }
  return string
}
