import React, { useState, useEffect, useRef, useCallback } from 'react'
import * as api from '../../api'
import * as storage from '../../util/storage'
import TopStats from './top-stats'
import { fetchTopStats } from './fetch-top-stats'
import { IntervalPicker, useStoredInterval } from './interval-picker'
import StatsExport from './stats-export'
import WithImportedSwitch from './with-imported-switch'
import { NoticesIcon } from './notices'
import * as url from '../../util/url'
import LineGraphWithRouter, { LineGraphContainer } from './line-graph'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Metric } from '../../../types/query-api'
import { DashboardPeriod } from '../../dashboard-time-periods'
import { DashboardState } from '../../dashboard-state'
import { nowForSite } from '../../util/date'
import { getStaleTime } from '../../hooks/api-client'
import { MainGraph, MainGraphContainer } from './main-graph'
import { createStatsQuery } from '../../stats-query'
function fetchMainGraph(
  site: PlausibleSite,
  dashboardState: DashboardState,
  metric: Metric,
  interval: string
) {
  const reportParams = {
    metrics: [metric],
    dimensions: [`time:${interval}`],
    include: {
      time_labels: true,
      present_index: true,
      partial_time_labels: true
    }
  }

  const statsQuery = createStatsQuery(dashboardState, reportParams)

  return api.stats(site, statsQuery)
}
// height of at least one row of top stats
const DEFAULT_TOP_STATS_LOADING_HEIGHT_PX = 85

export default function VisitorGraph({
  updateImportedDataInView
}: {
  updateImportedDataInView?: (v: boolean) => void
}) {
  const topStatsBoundary = useRef<HTMLDivElement>(null)
  const mainGraphContainer = useRef<HTMLDivElement>(null)
  const { width } = useMainGraphWidth(mainGraphContainer)
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const isRealtime = dashboardState.period === DashboardPeriod.realtime
  const queryClient = useQueryClient()
  const startOfDay = nowForSite(site).startOf('day')

  const { selectedInterval, onIntervalClick, availableIntervals } =
    useStoredInterval(site, {
      to: dashboardState.to,
      from: dashboardState.from,
      period: dashboardState.period
    })

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
    staleTime: ({ queryKey, meta }) => {
      const [_, opts] = queryKey
      return getStaleTime(
        meta!.startOfDay as typeof startOfDay,
        opts.dashboardState
      )
    },
    meta: { startOfDay }
  })

  const mainGraphQuery = useQuery({
    enabled: !!selectedMetric,
    queryKey: [
      'main-graph',
      { dashboardState, metric: selectedMetric!, interval: selectedInterval }
    ] as const,
    queryFn: async ({ queryKey }) => {
      const [_, opts] = queryKey
      const oldDataSource =
        window.location.hostname === 'localhost'
          ? 'http://localhost:8000'
          : window.location.hostname.match(/pr-\d+\.review\.plausible\.io/)
            ? 'https://staging.plausible.io'
            : ''
      const [dataOld, dataNew] = await Promise.all([
        api
          .get(
            `${oldDataSource}${url.apiPath(site, '/main-graph')}`,
            opts.dashboardState,
            {
              metric: opts.metric,
              interval: opts.interval
            }
          )
          .then((res) => ({ ...res, interval: opts.interval }))
          .catch(() => undefined),
        fetchMainGraph(site, opts.dashboardState, opts.metric, opts.interval)
          .then((res) => ({ ...res, period: opts.dashboardState.period }))
          .catch(() => undefined)
      ])
      return {
        dataOld,
        dataNew
      }
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey, meta }) => {
      const [_, opts] = queryKey
      return getStaleTime(
        meta!.startOfDay as typeof startOfDay,
        opts.dashboardState
      )
    },
    meta: { startOfDay }
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

  const [isRealtimeSilentUpdate, setIsRealtimeSilentUpdate] = useState({
    topStats: false,
    mainGraph: false
  })
  useEffect(() => {
    setIsRealtimeSilentUpdate((current) => ({ ...current, mainGraph: false }))
  }, [selectedMetric])

  useEffect(() => {
    if (!mainGraphQuery.isRefetching) {
      setIsRealtimeSilentUpdate((current) => ({ ...current, mainGraph: false }))
    }
  }, [mainGraphQuery.isRefetching])

  useEffect(() => {
    if (!topStatsQuery.isRefetching) {
      setIsRealtimeSilentUpdate((current) => ({ ...current, topStats: false }))
    }
  }, [topStatsQuery.isRefetching])

  useEffect(() => {
    if (!isRealtime) {
      setIsRealtimeSilentUpdate({
        topStats: false,
        mainGraph: false
      })
    }
  }, [isRealtime])

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
    const onTick = () => {
      setIsRealtimeSilentUpdate({ topStats: true, mainGraph: true })
      queryClient.invalidateQueries({
        predicate: ({ queryKey }) => {
          const realtimeTopStatsOrMainGraphQuery =
            ['top-stats', 'main-graph'].includes(queryKey[0] as string) &&
            typeof queryKey[1] === 'object' &&
            (queryKey[1] as { dashboardState?: DashboardState })?.dashboardState
              ?.period === DashboardPeriod.realtime

          return realtimeTopStatsOrMainGraphQuery
        }
      })
      refetchTopStats()
      refetchMainGraph()
    }

    if (isRealtime) {
      document.addEventListener('tick', onTick)
    }

    return () => {
      document.removeEventListener('tick', onTick)
    }
  }, [queryClient, isRealtime, refetchTopStats, refetchMainGraph])

  const importedSwitchVisible = !['no_imported_data', 'out_of_range'].includes(
    topStatsQuery.data?.meta.imports_skip_reason as string
  )

  const importedIntervalUnsupportedNotice =
    ['hour', 'minute'].includes(selectedInterval) &&
    importedSwitchVisible &&
    dashboardState.with_imported
      ? 'Interval is too short to graph imported data'
      : null

  const { heightPx } = useGuessTopStatsHeight(site, topStatsBoundary)

  const showFullLoader =
    topStatsQuery.isFetching &&
    topStatsQuery.isStale &&
    !isRealtimeSilentUpdate.topStats

  const showGraphLoader =
    mainGraphQuery.isFetching &&
    mainGraphQuery.isStale &&
    !isRealtimeSilentUpdate.mainGraph &&
    !showFullLoader

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
                height: `${heightPx}px`
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
            {mainGraphQuery.data?.dataNew && (
              <>
                {!showGraphLoader && (
                  <LineGraphWithRouter
                    graphData={mainGraphQuery.data.dataOld}
                  />
                )}
                {showGraphLoader && <Loader />}
              </>
            )}
          </LineGraphContainer>

          <MainGraphContainer ref={mainGraphContainer}>
            {mainGraphQuery.data?.dataNew && width && (
              <>
                {!showGraphLoader && (
                  <MainGraph width={width} data={mainGraphQuery.data.dataNew} />
                )}
                {showGraphLoader && <Loader />}
              </>
            )}
          </MainGraphContainer>
        </div>
      </>
      {(!(topStatsQuery.data && mainGraphQuery.data) || showFullLoader) && (
        <Loader />
      )}
    </div>
  )
}

const Loader = () => {
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

function useGuessTopStatsHeight(
  site: Pick<PlausibleSite, 'domain'>,
  topStatsBoundary: React.RefObject<HTMLDivElement>
): { heightPx: string } {
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
  }, [site, topStatsBoundary])

  return {
    heightPx:
      getStoredTopStatsHeight(site) ?? DEFAULT_TOP_STATS_LOADING_HEIGHT_PX
  }
}

function useMainGraphWidth(
  mainGraphContainer: React.RefObject<HTMLDivElement>
): { width: number } {
  const [width, setWidth] = useState<number>(0)

  useEffect(() => {
    const resizeObserver = new ResizeObserver(([e]) => {
      setWidth(e.contentRect.width)
    })

    if (mainGraphContainer.current) {
      resizeObserver.observe(mainGraphContainer.current)
    }

    return () => {
      resizeObserver.disconnect()
    }
  }, [mainGraphContainer])

  return {
    width
  }
}
