/* @format */

import React, { isValidElement } from 'react'
import { DashboardQuery, Filter, FilterClause } from '../query'
import { EVENT_PROPS_PREFIX, FILTER_OPERATIONS, FILTER_OPERATIONS_DISPLAY_NAMES, formattedFilters, getLabel, getPropertyKeyFromFilterKey } from './filters'



function formatClauses(clauseLabels: FilterClause[], joinWord: string) {
  return clauseLabels.reduce((prev, curr) => `${prev} ${joinWord} ${curr}`)
}

export function styledFilterText(query: DashboardQuery, [operation, filterKey, clauses]: Filter) {
  const formattedFilter = (formattedFilters as Record<string, string | undefined>)[filterKey]

  if (formattedFilter) {
    return (
      <>
        {formattedFilter} {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}{' '}
        {clauses
          .map((value, index) => (
            <>
              {index > 0 && ' or '}
              <b key={value}>{getLabel(query.labels, filterKey, value)}</b>
            </>
          ))}
      </>
    )
  } else if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return (
      <>
        Property <b>{propKey}</b> {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}{' '}
        {clauses
          .map((label, index) => (
            <>
              {index > 0 && ' or '}
              <b key={label}>{label}</b>
            </>
          ))}
      </>
    )
  }

  throw new Error(`Unknown filter: ${filterKey}`)
}

export function plainFilterText(query: DashboardQuery, filter: Filter) {
  return reactNodeToString(styledFilterText(query, filter))
}

function reactNodeToString(reactNode: React.ReactNode): string {
  let string = ""
  if (typeof reactNode === "string") {
    string = reactNode
  } else if (typeof reactNode === "number") {
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
