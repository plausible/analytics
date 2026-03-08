import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react'
import * as api from '../../api'
import * as storage from '../../util/storage'
import TopStats from './top-stats'
import { fetchTopStats } from './fetch-top-stats'
import {
  IntervalPicker,
  getDefaultInterval,
  getStoredInterval,
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
import { DashboardPeriod } from '../../dashboard-time-periods'
import { DashboardState } from '../../dashboard-state'
import { REALTIME_UPDATE_TIME_MS } from '../../util/realtime-update-timer'

// height of at least one row of top stats
const DEFAULT_TOP_STATS_LOADING_HEIGHT_PX = 85

// data cached by query client expires after 30 mins
const RESPONSES_STALE_TIME_MS = 30 * 60 * 1000

export default function VisitorGraph({
  updateImportedDataInView
}: {
  updateImportedDataInView?: (v: boolean) => void
}) {
  const topStatsBoundary = useRef<HTMLDivElement>(null)
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const isRealtime = dashboardState.period === DashboardPeriod.realtime

  const availableIntervals = validIntervals(site, dashboardState)

  const storedInterval = useMemo(
    () => getStoredInterval(dashboardState.period, site.domain),
    [dashboardState.period, site.domain]
  )

  const [selectedInterval, setSelectedInterval] = useState<string>(
    typeof storedInterval === 'string' &&
      availableIntervals.includes(storedInterval)
      ? storedInterval
      : getDefaultInterval(dashboardState, availableIntervals)
  )
  
  const onIntervalClick = useCallback(
    (interval: string) => {
      storeInterval(dashboardState.period, site.domain, interval)
      setSelectedInterval(interval)
    },
    [dashboardState.period, site.domain]
  )

  // update interval to one that exists
  useEffect(() => {
    setSelectedInterval((currentlySelectedMetric) => {
      // prefer stored interval
      if (
        typeof storedInterval === 'string' &&
        availableIntervals.includes(storedInterval)
      ) {
        return storedInterval
      }
      // prefer currently selected interval over default
      if (availableIntervals.includes(currentlySelectedMetric)) {
        return currentlySelectedMetric
      }

      return getDefaultInterval(dashboardState, availableIntervals)
    })
  }, [storedInterval, dashboardState, site, availableIntervals])

  const [selectedMetric, setSelectedMetric] = useState<Metric | null>(
    getStoredMetric(site)
  )
  const onMetricClick = useCallback(
    (metric: Metric) => {
      setStoredMetric(site, metric)
      setSelectedMetric(metric)
    },
    [site]
  )

  const topStatsQuery = useQuery({
    queryKey: ['top-stats', { dashboardState }] as const,
    queryFn: async ({ queryKey }) => {
      const [_, opts] = queryKey
      return await fetchTopStats(site, opts.dashboardState)
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey }) => {
      const [_, opts] = queryKey
      return getStaleTime(opts.dashboardState)
    }
  })

  const mainGraphQuery = useQuery({
    enabled: !!selectedMetric && availableIntervals.includes(selectedInterval),
    queryKey: [
      'main-graph',
      { dashboardState, metric: selectedMetric, interval: selectedInterval }
    ] as const,
    queryFn: async ({ queryKey }) => {
      const [_, opts] = queryKey
      return await api.get(
        url.apiPath(site, '/main-graph'),
        opts.dashboardState,
        {
          metric: opts.metric,
          interval: opts.interval
        }
      )
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey }) => {
      const [_, opts] = queryKey
      return getStaleTime(opts.dashboardState)
    }
  })

  // update metric to one that exists
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

  // sync import related info
  useEffect(() => {
    if (topStatsQuery.data && typeof updateImportedDataInView === 'function') {
      updateImportedDataInView(
        topStatsQuery.data.meta.imports_included as boolean
      )
    }
  }, [topStatsQuery.data, updateImportedDataInView])

  // fetch realtime stats
  const refetchTopStats = topStatsQuery.refetch
  const refetchMainGraph = mainGraphQuery.refetch

  useEffect(() => {
    const onTick = async () => {
      refetchTopStats()
      refetchMainGraph()
    }

    if (isRealtime) {
      document.addEventListener('tick', onTick)
    }

    return () => {
      document.removeEventListener('tick', onTick)
    }
  }, [isRealtime, refetchTopStats, refetchMainGraph])

  const importedSwitchVisible = !['no_imported_data', 'out_of_range'].includes(
    topStatsQuery.data?.meta.imports_skip_reason as string
  )

  const importedIntervalUnsupportedNotice =
    ['hour', 'minute'].includes(selectedInterval) &&
    importedSwitchVisible &&
    dashboardState.with_imported
      ? 'Interval is too short to graph imported data'
      : null

  // store current height of top stats 
  // to be able to loading the page from scratch with the correct height
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

  const showFullLoader = topStatsQuery.isFetching && topStatsQuery.isStale
  const showGraphLoader =
    mainGraphQuery.isFetching && mainGraphQuery.isStale && !showFullLoader

  return (
    <div className="col-span-full relative w-full bg-white rounded-md shadow dark:bg-gray-900">
      <>
        <div
          id="top-stats-container"
          className="flex flex-wrap relative"
          ref={topStatsBoundary}
        >
          {topStatsQuery.data ? (
            <TopStats
              data={topStatsQuery.data}
              selectedMetric={selectedMetric}
              onMetricClick={onMetricClick}
              tooltipBoundary={topStatsBoundary.current}
            />
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
                  [importedIntervalUnsupportedNotice].filter(
                    (n) => !!n
                  ) as string[]
                }
              />
              {!isRealtime && (
                <StatsExport selectedInterval={selectedInterval} />
              )}
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
                onIntervalClick={onIntervalClick}
                options={availableIntervals}
              />
            </div>
          )}
          <LineGraphContainer>
            {mainGraphQuery.data && (
              <>
                {!showGraphLoader && (
                  <LineGraphWithRouter
                    graphData={{
                      ...mainGraphQuery.data,
                      interval: selectedInterval
                    }}
                  />
                )}
                {showGraphLoader && <Loader />}
              </>
            )}
          </LineGraphContainer>
        </div>
      </>
      {(!(topStatsQuery.data && mainGraphQuery.data) || showFullLoader) && (
        <Loader />
      )}
    </div>
  )
}

function Loader() {
  return (
    <div className="absolute inset-0 bg-white rounded-md dark:bg-gray-900 flex items-center justify-center">
      <div className="loading">
        <div></div>
      </div>
    </div>
  )
}

function getStoredMetricKey(site: Pick<PlausibleSite, 'domain'>) {
  return storage.getDomainScopedStorageKey('metric', site.domain)
}

function getStoredMetric(site: Pick<PlausibleSite, 'domain'>) {
  return storage.getItem(getStoredMetricKey(site)) as Metric | null
}

function setStoredMetric(site: Pick<PlausibleSite, 'domain'>, metric: Metric) {
  storage.setItem(getStoredMetricKey(site), metric)
}

function getStoredTopStatsHeightKey(site: Pick<PlausibleSite, 'domain'>) {
  return storage.getDomainScopedStorageKey('topStatsHeight', site.domain)
}

function getStoredTopStatsHeight(site: Pick<PlausibleSite, 'domain'>) {
  return storage.getItem(getStoredTopStatsHeightKey(site)) as string
}

function setStoredTopStatsHeight(
  site: Pick<PlausibleSite, 'domain'>,
  heightPx: string
) {
  storage.setItem(getStoredTopStatsHeightKey(site), heightPx)
}

const getStaleTime = (dashboardState: DashboardState) => {
  if (dashboardState.period === DashboardPeriod.realtime) {
    // 2x multiplier is needed because otherwise queries cached before
    // tick N-1 would be marked as stale before tick N, which would cause loading
    // animation to be shown during tick N's refetch
    return 2 * REALTIME_UPDATE_TIME_MS
  }
  return RESPONSES_STALE_TIME_MS
}
