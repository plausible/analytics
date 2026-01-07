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
import { hasConversionGoalFilter, isRealTimeDashboard } from './util/filters'
import { useAppNavigate } from './navigation/use-app-navigate'
import { parseSearch } from './util/url-search-params'
import { getDomainScopedStorageKey } from './util/storage'

function DashboardStats({
  importedDataInView,
  updateImportedDataInView
}: {
  importedDataInView?: boolean
  updateImportedDataInView?: (v: boolean) => void
}) {
  const navigate = useAppNavigate()
  const site = useSiteContext()
  const { query } = useQueryContext()

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

  return (
    <>
      <VisitorGraph updateImportedDataInView={updateImportedDataInView} />
      <Sources />
      {site.flags.live_dashboard ? (
        <LiveViewPortal
          id="pages-breakdown-live"
          tabs={[
            {
              label: hasConversionGoalFilter(query)
                ? 'Conversion pages'
                : 'Top pages',
              value: 'pages'
            },
            { label: 'Entry pages', value: 'entry-pages' },
            { label: 'Exit pages', value: 'exit-pages' }
          ]}
          storageKey={getDomainScopedStorageKey('pageTab', site.domain)}
          className="w-full h-full border-0 overflow-hidden"
        />
      ) : (
        <Pages />
      )}

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
