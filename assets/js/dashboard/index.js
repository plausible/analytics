import React, { useState } from 'react';
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'

import { useQueryContext } from '../query-context';

export const statsBoxClass = "stats-item relative w-full mt-6 p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded"

function Dashboard(props) {
  const { site, loggedIn, currentUserRole } = props
  const { query, lastLoadTimestamp } = useQueryContext();
  const [importedDataInView, setImportedDataInView] = useState(false)

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
