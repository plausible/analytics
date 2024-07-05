import React, { useEffect, useState } from 'react';
import { withRouter } from 'react-router-dom'

import { useMountedEffect } from './custom-hooks';
import Historical from './historical'
import Realtime from './realtime'
import {parseQuery} from './query'
import * as api from './api'
import { getFiltersByKeyPrefix } from './util/filters';

export const statsBoxClass = "stats-item relative w-full mt-6 p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded"

function Dashboard(props) {
  const { location, site, loggedIn, currentUserRole } = props
  const [query, setQuery] = useState(parseQuery(location.search, site))
  const [importedDataInView, setImportedDataInView] = useState(false)
  
  // `revenueAvailable` keeps track of whether the current query includes a
  // non-empty goal filter set containing a single, or multiple revenue goals
  // with the same currency. Can be used to decide whether to render revenue
  // metrics in a dashboard report or not.
  const [revenueAvailable, setRevenueAvailable] = useState(false)
  const [lastLoadTimestamp, setLastLoadTimestamp] = useState(new Date())
  const updateLastLoadTimestamp = () => { setLastLoadTimestamp(new Date()) }

  useEffect(() => {
    document.addEventListener('tick', updateLastLoadTimestamp)

    return () => {
      document.removeEventListener('tick', updateLastLoadTimestamp)
    }
  }, [])

  useEffect(() => {
    const revenueGoalsInFilter = site.revenueGoals.filter((rg) => {
      const goalFilters = getFiltersByKeyPrefix(query, "goal")
      
      return goalFilters.some(([_op, _key, clauses]) => {
        return clauses.includes(rg.event_name)
      })
    })

    const singleCurrency = revenueGoalsInFilter.every((rg) => {
      return rg.currency === revenueGoalsInFilter[0].currency
    })

    setRevenueAvailable(revenueGoalsInFilter.length > 0 && singleCurrency)
  }, [query])

  useMountedEffect(() => {
    api.cancelAll()
    setQuery(parseQuery(location.search, site))
    updateLastLoadTimestamp()
  }, [location.search])

  if (query.period === 'realtime') {
    return (
      <Realtime
        site={site}
        loggedIn={loggedIn}
        currentUserRole={currentUserRole}
        query={query}
        lastLoadTimestamp={lastLoadTimestamp}
        revenueAvailable={revenueAvailable}
      />
    )
  } else {
    return (
      <Historical
        site={site}
        loggedIn={loggedIn}
        currentUserRole={currentUserRole}
        query={query}
        lastLoadTimestamp={lastLoadTimestamp}
        importedDataInView={importedDataInView}
        updateImportedDataInView={setImportedDataInView}
        revenueAvailable={revenueAvailable}
      />
    )
  }
}

export default withRouter(Dashboard)
