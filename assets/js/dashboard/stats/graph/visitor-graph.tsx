import React, { useState, useEffect, useRef, useCallback } from 'react'
import * as storage from '../../util/storage'
import TopStats from './top-stats'
import { useTopStatsQuery } from './fetch-top-stats'
import { useMainGraphQuery } from './fetch-main-graph'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { Metric } from '../metrics'
import { MainGraph, MainGraphContainer, useMainGraphWidth } from './main-graph'
import { useGraphIntervalContext } from './graph-interval-context'
import { useSetImportsIncluded } from './imports-included-context'

// height of at least one row of top stats
const DEFAULT_TOP_STATS_LOADING_HEIGHT_PX = 85
const DEFAULT_GRAPH_METRIC = 'visitors'

export default function VisitorGraph({
  updateImportedDataInView
}: {
  updateImportedDataInView?: (v: boolean) => void
}) {
  const topStatsBoundary = useRef<HTMLDivElement>(null)
  const mainGraphContainer = useRef<HTMLDivElement>(null)
  const { width } = useMainGraphWidth(mainGraphContainer)
  const site = useSiteContext()

  const { selectedInterval } = useGraphIntervalContext()

  const [selectedMetric, setSelectedMetric] = useState<Metric>(
    getStoredMetric(site) || DEFAULT_GRAPH_METRIC
  )
  const onMetricClick = useCallback(
    (metric: Metric) => {
      setStoredMetric(site, metric)
      setSelectedMetric(metric)
    },
    [site]
  )

  const {
    apiState: topStatsApiState,
    isRealtimeSilentUpdate: isTopStatsRealtimeSilentUpdate
  } = useTopStatsQuery()

  const {
    apiState: mainGraphApiState,
    isRealtimeSilentUpdate: isMainGraphRealtimeSilentUpdate
  } = useMainGraphQuery(selectedMetric, selectedInterval)

  // Fall back to default graph metric if the stored metric
  // does not exist in the returned Top Stats
  useEffect(() => {
    if (topStatsApiState.data) {
      const availableMetrics = topStatsApiState.data.query.metrics

      setSelectedMetric((currentlySelectedMetric) => {
        if (
          currentlySelectedMetric &&
          availableMetrics.includes(currentlySelectedMetric)
        ) {
          return currentlySelectedMetric
        } else {
          return DEFAULT_GRAPH_METRIC
        }
      })
    }
  }, [topStatsApiState.data])

  // sync import related info
  useEffect(() => {
    if (
      topStatsApiState.data &&
      typeof updateImportedDataInView === 'function'
    ) {
      updateImportedDataInView(
        topStatsApiState.data.meta.imports_included as boolean
      )
    }
  }, [topStatsApiState.data, updateImportedDataInView])

  const switchVisible = !['no_imported_data', 'out_of_range'].includes(
    topStatsApiState.data?.meta.imports_skip_reason as string
  )
  const switchDisabled =
    topStatsApiState.data?.meta.imports_skip_reason === 'unsupported_query'

  const setImportsIncluded = useSetImportsIncluded()

  useEffect(() => {
    if (topStatsApiState.data) {
      setImportsIncluded({ switchVisible, switchDisabled })
    } else {
      setImportsIncluded(null)
    }
  }, [topStatsApiState.data, switchVisible, switchDisabled, setImportsIncluded])

  useEffect(() => {
    return () => setImportsIncluded(null)
  }, [setImportsIncluded])

  const { heightPx } = useGuessTopStatsHeight(site, topStatsBoundary)

  const showFullLoader =
    topStatsApiState.isFetching &&
    topStatsApiState.isStale &&
    !isTopStatsRealtimeSilentUpdate

  const showGraphLoader =
    mainGraphApiState.isFetching &&
    mainGraphApiState.isStale &&
    !isMainGraphRealtimeSilentUpdate &&
    !showFullLoader

  return (
    <div className="col-span-full relative w-full bg-white rounded-md shadow-sm dark:bg-gray-900">
      <>
        <div
          id="top-stats-container"
          className="flex flex-wrap relative"
          ref={topStatsBoundary}
        >
          {topStatsApiState.data ? (
            <TopStats
              data={topStatsApiState.data}
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
            {!!mainGraphApiState.data && !!width && (
              <>
                {!showGraphLoader && (
                  <MainGraph width={width} data={mainGraphApiState.data} />
                )}
                {showGraphLoader && <Loader />}
              </>
            )}
          </MainGraphContainer>
        </div>
      </>
      {(!(topStatsApiState.data && mainGraphApiState.data) ||
        showFullLoader) && <Loader />}
    </div>
  )
}

const Loader = () => {
  return (
    <div
      data-testid="loading-spinner"
      className="absolute inset-0 bg-white rounded-md dark:bg-gray-900 flex items-center justify-center"
    >
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
