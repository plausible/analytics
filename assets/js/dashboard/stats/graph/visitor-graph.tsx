import React, { useState, useEffect, useRef, useCallback } from 'react'
import * as storage from '../../util/storage'
import TopStats from './top-stats'
import { fetchTopStats } from './fetch-top-stats'
import { fetchMainGraph } from './fetch-main-graph'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Metric } from '../../../types/query-api'
import { DashboardPeriod } from '../../dashboard-time-periods'
import { DashboardState } from '../../dashboard-state'
import { getStaleTime } from '../../hooks/api-client'
import { MainGraph, MainGraphContainer, useMainGraphWidth } from './main-graph'
import { useGraphIntervalContext } from './graph-interval-context'
import { useSetImportsIncluded } from './imports-included-context'

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

  const { selectedInterval } = useGraphIntervalContext()

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
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...opts.dashboardState
      })
    }
  })

  const mainGraphQuery = useQuery({
    enabled: !!selectedMetric,
    queryKey: [
      'main-graph',
      { dashboardState, metric: selectedMetric!, interval: selectedInterval }
    ] as const,
    queryFn: async ({ queryKey }) => {
      const [_, opts] = queryKey
      const data = await fetchMainGraph(
        site,
        opts.dashboardState,
        opts.metric,
        opts.interval
      )

      // pack dashboard period and interval used for the request next to data
      // so they'd never be out of sync with each other
      return {
        ...data,
        period: opts.dashboardState.period,
        interval: opts.interval
      }
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey }) => {
      const [_, opts] = queryKey
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...opts.dashboardState
      })
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
    }

    if (isRealtime) {
      document.addEventListener('tick', onTick)
    }

    return () => {
      document.removeEventListener('tick', onTick)
    }
  }, [queryClient, isRealtime])

  const switchVisible = !['no_imported_data', 'out_of_range'].includes(
    topStatsQuery.data?.meta.imports_skip_reason as string
  )
  const switchDisabled =
    topStatsQuery.data?.meta.imports_skip_reason === 'unsupported_query'

  const setImportsIncluded = useSetImportsIncluded()

  useEffect(() => {
    if (topStatsQuery.data) {
      setImportsIncluded({ switchVisible, switchDisabled })
    } else {
      setImportsIncluded(null)
    }
  }, [topStatsQuery.data, switchVisible, switchDisabled, setImportsIncluded])

  useEffect(() => {
    return () => setImportsIncluded(null)
  }, [setImportsIncluded])

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
    <div className="col-span-full relative w-full bg-white rounded-md shadow-sm dark:bg-gray-900">
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
        <div className="relative flex flex-col pl-3 pr-4">
          <MainGraphContainer ref={mainGraphContainer}>
            {!!mainGraphQuery.data && !!width && (
              <>
                {!showGraphLoader && (
                  <MainGraph width={width} data={mainGraphQuery.data} />
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
