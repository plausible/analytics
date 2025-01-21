/** @format */

import React, { useMemo, useState } from 'react'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations'
import Devices from './stats/devices'
import { TopBar } from './nav-menu/top-bar'
import Behaviours from './stats/behaviours'
import { FiltersBar } from './nav-menu/filters-bar'
import { useQueryContext } from './query-context'
import { isRealTimeDashboard } from './util/filters'

function DashboardStats({
  importedDataInView,
  updateImportedDataInView
}: {
  importedDataInView?: boolean
  updateImportedDataInView?: (v: boolean) => void
}) {
  const statsBoxClass =
    'stats-item relative w-full mt-6 p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded'

  return (
    <>
      <VisitorGraph updateImportedDataInView={updateImportedDataInView} />
      <div className="w-full md:flex">
        <div className={statsBoxClass}>
          <Sources />
        </div>
        <div className={statsBoxClass}>
          <Pages />
        </div>
      </div>

      <div className="w-full md:flex">
        <div className={statsBoxClass}>
          <Locations />
        </div>
        <div className={statsBoxClass}>
          <Devices />
        </div>
      </div>

      <Behaviours importedDataInView={importedDataInView} />
    </>
  )
}

function useIsRealtimeDashboard() {
  const {
    query: { period }
  } = useQueryContext()
  return useMemo(() => isRealTimeDashboard({ period }), [period])
}

function Dashboard() {
  const isRealTimeDashboard = useIsRealtimeDashboard()
  const [importedDataInView, setImportedDataInView] = useState(false)

  return (
    <div className="mb-12">
      <TopBar
        showCurrentVisitors={!isRealTimeDashboard}
        extraBar={<FiltersBar />}
      />
      <DashboardStats
        importedDataInView={
          isRealTimeDashboard ? undefined : importedDataInView
        }
        updateImportedDataInView={
          isRealTimeDashboard ? undefined : setImportedDataInView
        }
      />
    </div>
  )
}

export default Dashboard
