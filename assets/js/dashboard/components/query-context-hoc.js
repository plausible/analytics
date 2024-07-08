import React, { useState, useEffect} from "react"
import * as api from '../api'
import { useMountedEffect } from '../custom-hooks'
import { parseQuery } from "../query"

// A Higher-Order component that tracks `query` state, and additional context
// related to it, such as:

// * `importedDataInView` - simple state with a `false` default. An
//   `updateImportedDataInView` prop will be passed into the WrappedComponent
//   and allows changing that according to responses from the API.

// * `lastLoadTimestamp` - used for displaying a tooltip with time passed since
//   the last update in realtime components.

export default function withQueryContext(WrappedComponent) {
  return (props) => {
    const { site, location } = props
    
    const [query, setQuery] = useState(parseQuery(location.search, site))
    const [importedDataInView, setImportedDataInView] = useState(false)
    const [lastLoadTimestamp, setLastLoadTimestamp] = useState(new Date())
    
    const updateLastLoadTimestamp = () => { setLastLoadTimestamp(new Date()) }

    useEffect(() => {
      document.addEventListener('tick', updateLastLoadTimestamp)

      return () => {
        document.removeEventListener('tick', updateLastLoadTimestamp)
      }
    }, [])

    useMountedEffect(() => {
      api.cancelAll()
      setQuery(parseQuery(location.search, site))
      updateLastLoadTimestamp()
    }, [location.search])

    return (
      <WrappedComponent
        {...props}
        query={query}
        importedDataInView={importedDataInView}
        updateImportedDataInView={setImportedDataInView}
        lastLoadTimestamp={lastLoadTimestamp}
      />
    )
  }
}