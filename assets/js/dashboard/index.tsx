import React, { useMemo, useState } from 'react'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import { PagesLive } from './stats/live'
import Locations from './stats/locations'
import Devices from './stats/devices'
import { TopBar } from './nav-menu/top-bar'
import Behaviours from './stats/behaviours'
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
    'relative min-h-[436px] w-full mt-5 p-4 flex flex-col bg-white dark:bg-gray-900 shadow-sm rounded-md md:min-h-initial md:h-27.25rem md:w-[calc(50%-10px)] md:ml-[10px] md:mr-[10px] first:ml-0 last:mr-0'

  return (
    <>
      <VisitorGraph updateImportedDataInView={updateImportedDataInView} />
      <div className="w-full md:flex">
        <div className={statsBoxClass}>
          <Sources />
        </div>
        <div className={statsBoxClass}>
          <PagesLive />
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
    <div className="mb-16">
      <TopBar showCurrentVisitors={!isRealTimeDashboard} />
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
