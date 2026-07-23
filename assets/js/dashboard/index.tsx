import React, { useMemo, useState } from 'react'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import { Locations } from './stats/locations'
import { Devices } from './stats/devices'
import { TopBar } from './nav-menu/top-bar'
import Behaviours from './stats/behaviours'
import { useDashboardStateContext } from './dashboard-state-context'
import { isRealTimeDashboard } from './util/filters'
import { GraphIntervalProvider } from './stats/graph/graph-interval-context'
import { ImportsIncludedProvider } from './stats/graph/imports-included-context'
import { CurrentVisitorsProvider } from './current-visitors-context'
import { VerificationLiveViewPortal } from './verification/portal'
import { EmailReportsCTABanner } from './email-reports-cta-banner'

function DashboardStats({
  importedDataInView,
  updateImportedDataInView
}: {
  importedDataInView?: boolean
  updateImportedDataInView?: (v: boolean) => void
}) {
  return (
    <>
      <div className="col-span-full">
        <EmailReportsCTABanner />
        <VerificationLiveViewPortal />
        <VisitorGraph updateImportedDataInView={updateImportedDataInView} />
      </div>
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
    dashboardState: { period }
  } = useDashboardStateContext()
  return useMemo(() => isRealTimeDashboard({ period }), [period])
}

function Dashboard() {
  const isRealTimeDashboard = useIsRealtimeDashboard()
  const [importedDataInView, setImportedDataInView] = useState(false)

  return (
    <CurrentVisitorsProvider>
      <GraphIntervalProvider>
        <ImportsIncludedProvider>
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
        </ImportsIncludedProvider>
      </GraphIntervalProvider>
    </CurrentVisitorsProvider>
  )
}

export default Dashboard
