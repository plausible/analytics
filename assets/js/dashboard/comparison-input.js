import React from 'react'
import { withRouter } from "react-router-dom";
import { navigateToQuery } from './query'

const DISABLED_PERIODS = ['realtime', 'all']

const ComparisonInput = function({ _graphData, query, history }) {
  if (DISABLED_PERIODS.includes(query.period)) return null

  function update(event) {
    navigateToQuery(history, query, { comparison: event.target.checked })
  }

  return (
    <div className="flex-none mx-3">
      <input id="comparison-input" type="checkbox" onChange={update} checked={query.comparison} className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
      <label htmlFor="comparison-input" className="ml-1.5 font-medium text-xs md:text-sm text-gray-700">Compare</label>
    </div>
  )
}

export default withRouter(ComparisonInput)
