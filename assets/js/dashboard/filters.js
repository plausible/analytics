import React from 'react';
import { withRouter } from 'react-router-dom'
import {removeQueryParam} from './query'

function Filters({query, history, location}) {
  if (query.filters.goal) {
    function removeGoal() {
      history.push({search: removeQueryParam(location.search, 'goal')})
    }

    return (
      <div className="mt-4">
        <span className="bg-white text-gray-700 shadow text-sm rounded py-2 px-3">
          Completed goal <b>{query.filters.goal}</b> <b className="ml-1 cursor-pointer" onClick={removeGoal}>✕</b>
        </span>
      </div>
    )
  }

  return null
}

export default withRouter(Filters)
