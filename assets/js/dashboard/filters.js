import React from 'react';
import { withRouter } from 'react-router-dom'
import {removeQueryParam} from './query'

function filterText(key, value) {
  if (key === "goal") {
    return <span className="inline-block max-w-sm truncate">Completed goal <b>{value}</b></span>
  }
  if (key === "source") {
    return <span className="inline-block max-w-sm truncate">Source: <b>{value}</b></span>
  }
  if (key === "referrer") {
    return <span className="inline-block max-w-sm truncate">Referrer: <b>{value}</b></span>
  }
  if (key === "page") {
    return <span className="inline-block max-w-sm truncate">Page: <b>{value}</b></span>
  }
}

function renderFilter(history, [key, value]) {
  function removeFilter() {
    history.push({search: removeQueryParam(location.search, key)})
  }

  return (
    <span key={key} title={value} className="inline-flex bg-white text-gray-700 shadow text-sm rounded py-2 px-3 mr-4">
      {filterText(key, value)} <b className="ml-1 cursor-pointer" onClick={removeFilter}>✕</b>
    </span>
  )
}

function Filters({query, history, location}) {
  const appliedFilters = Object.keys(query.filters)
    .map((key) => [key, query.filters[key]])
    .filter(([key, value]) => !!value)

  if (appliedFilters.length > 0) {
    return (
      <div className="mt-4">
        { appliedFilters.map((filter) => renderFilter(history, filter)) }
      </div>
    )
  }

  return null
}

export default withRouter(Filters)
