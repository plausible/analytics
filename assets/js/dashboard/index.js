import React from 'react'
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'
import withQueryContext from './components/query-context-hoc';

export const statsBoxClass = "stats-item relative w-full mt-6 p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded"

function Dashboard(props) {
  const {
    site,
    loggedIn,
    currentUserRole,
    query,
    revenueAvailable,
    importedDataInView,
    updateImportedDataInView,
    lastLoadTimestamp
  } = props

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
        updateImportedDataInView={updateImportedDataInView}
        revenueAvailable={revenueAvailable}
      />
    )
  }
}

export default withRouter(withQueryContext(Dashboard))
