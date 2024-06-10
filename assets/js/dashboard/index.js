import React, { useEffect, useState } from 'react';
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'
import {parseQuery} from './query'
import * as api from './api'

export const statsBoxClass = "stats-item relative w-full mt-6 p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded"

function Dashboard(props) {
  const { location, site, loggedIn, currentUserRole } = props
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

  useEffect(() => {
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
      />
    )
  }
}

export default withRouter(Dashboard)
