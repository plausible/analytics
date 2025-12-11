import React, { useMemo, useState, useEffect, useCallback } from 'react'
import { LiveViewPortal } from './components/liveview-portal'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations'
import Devices from './stats/devices'
import { TopBar } from './nav-menu/top-bar'
import Behaviours from './stats/behaviours'
import { useQueryContext } from './query-context'
import { useSiteContext } from './site-context'
import { isRealTimeDashboard } from './util/filters'
import { useAppNavigate } from './navigation/use-app-navigate'
import { parseSearch } from './util/url-search-params'

function DashboardStats({
  importedDataInView,
  updateImportedDataInView
}: {
  importedDataInView?: boolean
  updateImportedDataInView?: (v: boolean) => void
}) {
  const navigate = useAppNavigate()
  const site = useSiteContext()

  // Handler for navigation events delegated from LiveView dashboard.
  // Necessary to emulate navigation events in LiveView with pushState
  // manipulation disabled.
  const onLiveNavigate = useCallback(
    (e: CustomEvent) => {
      navigate({
        path: e.detail.path,
        search: () => parseSearch(e.detail.search)
      })
    },
    [navigate]
  )

  useEffect(() => {
    window.addEventListener(
      'dashboard:live-navigate',
      onLiveNavigate as EventListener
    )

    return () => {
      window.removeEventListener(
        'dashboard:live-navigate',
        onLiveNavigate as EventListener
      )
    }
  }, [onLiveNavigate])

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
          {site.flags.live_dashboard ? (
            <LiveViewPortal
              id="pages-breakdown-live"
              className="w-full h-full border-0 overflow-hidden"
            />
          ) : (
            <Pages />
          )}
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
