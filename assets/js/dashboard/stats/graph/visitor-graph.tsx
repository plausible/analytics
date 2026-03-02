import React, { useState, useEffect, useRef } from 'react'
import * as api from '../../api'
import * as storage from '../../util/storage'
import TopStats from './top-stats'
import { fetchTopStats } from './fetch-top-stats'
import {
  IntervalPicker,
  getCurrentInterval,
  getDefaultInterval,
  storeInterval,
  validIntervals
} from './interval-picker'
import StatsExport from './stats-export'
import WithImportedSwitch from './with-imported-switch'
import { NoticesIcon } from './notices'
import * as url from '../../util/url'
import LineGraphWithRouter, { LineGraphContainer } from './line-graph'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { useQuery } from '@tanstack/react-query'
import { Metric } from '../../../types/query-api'

// height of at least one row of top stats
const DEFAULT_TOP_STATS_LOADING_HEIGHT_PX = 85

export default function VisitorGraph({
  updateImportedDataInView
}: {
  updateImportedDataInView?: (v: boolean) => void
}) {
  const topStatsBoundary = useRef<HTMLDivElement>(null)
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const [selectedInterval, setSelectedInterval] = useState<string>(
    getCurrentInterval(site, dashboardState)
  )
  const [selectedMetric, setSelectedMetric] = useState<Metric | null>(
    getStoredMetric(site)
  )

  const topStatsQuery = useQuery({
    queryKey: ['top-stats', { dashboardState }] as const,
    queryFn: async ({ queryKey }) => {
      const [_, { dashboardState }] = queryKey
      return await fetchTopStats(site, dashboardState)
    },
    placeholderData: (previousData) => previousData,
    staleTime: Infinity
  })

  const mainGraphQuery = useQuery({
    enabled: !!selectedMetric,
    queryKey: [
      'main-graph',
      { dashboardState, metric: selectedMetric, interval: selectedInterval }
    ] as const,
    queryFn: async ({ queryKey }) => {
      const [_, { dashboardState, metric, interval }] = queryKey
      return await api.get(url.apiPath(site, '/main-graph'), dashboardState, {
        metric,
        interval
      })
    },
    placeholderData: (previousData) => previousData,
    staleTime: Infinity
  })

  // select metric that exists
  useEffect(() => {
    if (topStatsQuery.data) {
      const availableMetrics = topStatsQuery.data.topStats
        .filter((stat) => stat.graphable)
        .map((stat) => stat.metric)

      setSelectedMetric((currentlySelectedMetric) => {
        if (
          currentlySelectedMetric &&
          availableMetrics.includes(currentlySelectedMetric)
        ) {
          return currentlySelectedMetric
        } else {
          return availableMetrics[0]
        }
      })
    }
  }, [topStatsQuery.data])

  // select interval that is allowed
  useEffect(() => {
    if (topStatsQuery.data) {
      const availableIntervals = validIntervals(site, dashboardState)

      setSelectedInterval((currentlySelectedInterval) => {
        if (
          currentlySelectedInterval &&
          availableIntervals.includes(currentlySelectedInterval)
        ) {
          return currentlySelectedInterval
        } else {
          return getDefaultInterval(dashboardState, availableIntervals)
        }
      })
    }
  }, [site, dashboardState, topStatsQuery.data])

  // sync import related info
  useEffect(() => {
    if (topStatsQuery.data && typeof updateImportedDataInView === 'function') {
      updateImportedDataInView(
        topStatsQuery.data.meta.imports_included as boolean
      )
    }
  }, [topStatsQuery.data, updateImportedDataInView])

  // save preferred metric for the dashboard
  useEffect(() => {
    if (selectedMetric) {
      setStoredMetric(site, selectedMetric)
    }
  }, [site, selectedMetric])

  // save preferred interval for the dashboard & period
  useEffect(() => {
    if (validIntervals(site, dashboardState).includes(selectedInterval)) {
      storeInterval(dashboardState.period, site.domain, selectedInterval)
    }
  }, [dashboardState, site, selectedInterval])

  const isRealtime = dashboardState.period === 'realtime'
  const refetchTopStats = topStatsQuery.refetch

  useEffect(() => {
    const updateTopStats = () => refetchTopStats()

    if (isRealtime) {
      document.addEventListener('tick', updateTopStats)
    }

    return () => {
      document.removeEventListener('tick', updateTopStats)
    }
  }, [isRealtime, refetchTopStats])

  const importedSwitchVisible = !['no_imported_data', 'out_of_range'].includes(
    topStatsQuery.data?.meta.imports_skip_reason as string
  )

  const importedIntervalUnsupportedNotice =
    ['hour', 'minute'].includes(selectedInterval) &&
    importedSwitchVisible &&
    dashboardState.with_imported
      ? 'Interval is too short to graph imported data'
      : null

  useEffect(() => {
    const resizeObserver = new ResizeObserver(() => {
      if (topStatsBoundary.current) {
        setStoredTopStatsHeight(
          site,
          `${Math.max(topStatsBoundary.current.clientHeight, DEFAULT_TOP_STATS_LOADING_HEIGHT_PX)}`
        )
      }
    })

    if (topStatsBoundary.current) {
      resizeObserver.observe(topStatsBoundary.current)
    }

    return () => {
      resizeObserver.disconnect()
    }
  }, [site])

  return (
    <div className="col-span-full relative w-full bg-white rounded-md shadow dark:bg-gray-900">
      <div
        id="top-stats-container"
        className="flex flex-wrap relative"
        ref={topStatsBoundary}
      >
        {topStatsQuery.data ? (
          <>
            <TopStats
              data={topStatsQuery.data}
              selectedMetric={selectedMetric}
              setSelectedMetric={setSelectedMetric}
              tooltipBoundary={topStatsBoundary.current}
            />
            {topStatsQuery.isFetching && <Loader />}
          </>
        ) : (
          // prevent the top stats area from jumping on initial load
          <div
            style={{
              height: `${getStoredTopStatsHeight(site) ?? DEFAULT_TOP_STATS_LOADING_HEIGHT_PX}px`
            }}
          ></div>
        )}
      </div>
      <div className="relative px-2">
        {topStatsQuery.data && (
          <div className="absolute right-4 -top-8 py-1 flex items-center gap-x-4">
            <NoticesIcon
              notices={
                [
                  importedIntervalUnsupportedNotice
                  // getSamplingNotice(topStatsQuery.data)
                ].filter((n) => !!n) as string[]
              }
            />
            {!isRealtime && <StatsExport selectedInterval={selectedInterval} />}
            {importedSwitchVisible && (
              <WithImportedSwitch
                tooltipMessage={
                  topStatsQuery.data.meta.imports_skip_reason ===
                  'unsupported_query'
                    ? 'Imported data cannot be included'
                    : topStatsQuery.data.meta.imports_included
                      ? 'Click to exclude imported data'
                      : 'Click to include imported data'
                }
                disabled={
                  topStatsQuery.data.meta.imports_skip_reason ===
                  'unsupported_query'
                }
              />
            )}
            <IntervalPicker
              selectedInterval={selectedInterval}
              setSelectedInterval={setSelectedInterval}
              options={validIntervals(site, dashboardState)}
            />
          </div>
        )}
        <LineGraphContainer>
          {mainGraphQuery.data && (
            <>
              <LineGraphWithRouter
                graphData={{
                  ...mainGraphQuery.data,
                  interval: selectedInterval
                }}
              />
              {mainGraphQuery.isFetching && <Loader />}
            </>
          )}
        </LineGraphContainer>
      </div>
      {!topStatsQuery.data && !mainGraphQuery.data && <Loader />}
    </div>
  )
}

function Loader() {
  return (
    <div className="absolute inset-0 flex items-center justify-center">
      <div className="loading">
        <div></div>
      </div>
    </div>
  )
}

function getStoredMetric(site: PlausibleSite) {
  return storage.getItem(`metric__${site.domain}`) as Metric | null
}

function setStoredMetric(site: PlausibleSite, metric: string) {
  storage.setItem(`metric__${site.domain}`, metric)
}

function getStoredTopStatsHeight(site: PlausibleSite) {
  return storage.getItem(`topStatsHeight__${site.domain}`) as string
}

function setStoredTopStatsHeight(site: PlausibleSite, heightStyle: string) {
  storage.setItem(`topStatsHeight__${site.domain}`, heightStyle)
}
