import React, { useState, useEffect} from "react"
import * as api from '../api'
import { useMountedEffect } from '../custom-hooks'
import { parseQuery } from "../query"
import { getFiltersByKeyPrefix } from '../util/filters'

// A Higher-Order component that tracks `query` state, and additional context
// related to it, such as:

// * `importedDataInView` - simple state with a `false` default. An
//   `updateImportedDataInView` prop will be passed into the WrappedComponent
//   and allows changing that according to responses from the API.

// * `revenueAvailable` - keeps track of whether the current query includes a
//   non-empty goal filterset containing a single, or multiple revenue goals
//   with the same currency. Can be used to decide whether to render revenue
//   metrics in a dashboard report or not.

// * `lastLoadTimestamp` - used for displaying a tooltip with time passed since
//   the last update in realtime components.

export default function withQueryContext(WrappedComponent) {
  return (props) => {
    const { site, location } = props
    
    const [query, setQuery] = useState(parseQuery(location.search, site))
    const [importedDataInView, setImportedDataInView] = useState(false)
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

    return (
      <WrappedComponent
        {...props}
        query={query}
        revenueAvailable={revenueAvailable}
        importedDataInView={importedDataInView}
        updateImportedDataInView={setImportedDataInView}
        lastLoadTimestamp={lastLoadTimestamp}
      />
    )
  }
}