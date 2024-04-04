import React, { useState, useEffect, useRef, useCallback } from 'react';
import * as api from '../../api'
import * as storage from '../../util/storage'
import TopStats from './top-stats';
import { IntervalPicker } from './interval-picker'
import StatsExport from './stats-export'
import WithImportedSwitch from './with-imported-switch';
import SamplingNotice from './sampling-notice';
import FadeIn from '../../fade-in';
import * as url from '../../util/url'
import LineGraphWithRouter from './line-graph'

const LoadingState = {
  LOADING: 'loading',
  UPDATING_GRAPH: 'updatingGraph',
  READY: 'ready'
}

function fetchTopReport(site, query, metric, interval) {
  return api.get(url.apiPath(site, '/top-report'), query, {metric, interval})
}

function fetchMainGraph(site, query, metric, interval) {
  return api.get(url.apiPath(site, '/main-graph'), query, {metric, interval})
}

export default function VisitorGraph(props) {
  const {site, query, lastLoadTimestamp} = props
  const isRealtime = query.period === 'realtime'
  const isDarkTheme = document.querySelector('html').classList.contains('dark') || false

  const topStatsBoundary = useRef(null)

  const [topStatData, setTopStatData] = useState(null)
  const [graphData, setGraphData] = useState(null)
  const [loadingState, setLoadingState] = useState(LoadingState.LOADING)

  const onIntervalUpdate = useCallback((newInterval) => {
    storage.setInterval(site, query, newInterval)
    setGraphData(null)
    setLoadingState(LoadingState.UPDATING_GRAPH)
    fetchGraphData(storage.getMetric(site), newInterval)
  }, [query])

  const onMetricUpdate = useCallback((newMetric) => {
    storage.setMetric(site, newMetric)
    setGraphData(null)
    setLoadingState(LoadingState.UPDATING_GRAPH)
    fetchGraphData(newMetric, storage.getInterval(site, query))
  }, [query])

  useEffect(() => {
    setTopStatData(null)
    setGraphData(null)
    setLoadingState(LoadingState.LOADING)
    fetchTopStatsAndGraphData()

    if (isRealtime) {
      document.addEventListener('tick', fetchTopStatsAndGraphData)
    }

    return () => {
      document.removeEventListener('tick', fetchTopStatsAndGraphData)
    }
  }, [query])

  useEffect(() => {
    if (topStatData) { storeTopStatsContainerHeight() }
  }, [topStatData])

  function fetchTopStatsAndGraphData() {
    const metric = storage.getMetric(site)
    const interval = storage.getInterval(site, query)

    fetchTopReport(site, query, metric, interval)
      .then((res) => {
        storage.setInterval(site, query, res.interval)
        storage.setMetric(site, res.metric)
        setTopStatData(res)
        setGraphData(res)
        setLoadingState(LoadingState.READY)
      })
  }

  function fetchGraphData(metric, interval) {
    fetchMainGraph(site, query, metric, interval)
      .then((res) => {
        setGraphData(res)
        setLoadingState(LoadingState.READY)
      })
  }

  function storeTopStatsContainerHeight() {
    storage.setItem(`topStatsHeight__${site.domain}`, document.getElementById('top-stats-container').clientHeight)
  }

  // This function is used for maintaining the main-graph/top-stats container height in the
  // loading process. The container height depends on how many top stat metrics are returned
  // from the API, but in the loading state, we don't know that yet. We can use localStorage
  // to keep track of the Top Stats container height.
  function getTopStatsHeight() {
    if (topStatData) {
      return 'auto'
    } else {
      return `${storage.getItem(`topStatsHeight__${site.domain}`) || 89}px`
    }
  }


  return (
    <div className={"relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825"}>
      {loadingState == LoadingState.LOADING && renderLoader()}
      <FadeIn show={loadingState !== LoadingState.LOADING}>
        <div id="top-stats-container" className="flex flex-wrap" ref={topStatsBoundary} style={{ height: getTopStatsHeight() }}>
          <TopStats site={site} query={query} data={topStatData} onMetricUpdate={onMetricUpdate} tooltipBoundary={topStatsBoundary.current} lastLoadTimestamp={lastLoadTimestamp} />
        </div>
        <div className="relative px-2">
          {loadingState === LoadingState.UPDATING_GRAPH && renderLoader()}
          <div className="absolute right-4 -top-8 py-1 flex items-center">
            {!isRealtime && <StatsExport site={site} query={query} />}
            <SamplingNotice samplePercent={topStatData}/>
            <WithImportedSwitch site={site} topStatData={topStatData} />
            <IntervalPicker query={query} currentInterval={storage.getInterval(site, query)} options={topStatData?.valid_intervals || []} onIntervalUpdate={onIntervalUpdate} />
          </div>
          <LineGraphWithRouter graphData={graphData} darkTheme={isDarkTheme} query={query} />
        </div>
      </FadeIn>
    </div>
  )
}

function renderLoader() {
  return (
    <div className="absolute h-full w-full flex items-center justify-center">
      <div className="loading">
        <div></div>
      </div>
    </div>
  )
}
