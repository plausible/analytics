import React, { useMemo, useState } from 'react'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
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

  return (
    <>
      <VisitorGraph updateImportedDataInView={updateImportedDataInView} />
      <Sources />
      <Pages />
      <Locations />
      <Devices />
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
    <div className="mb-16 grid grid-cols-1 md:grid-cols-2 gap-5">
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
