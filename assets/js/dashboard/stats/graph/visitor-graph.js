import React, { useState, useEffect, useRef, useCallback } from 'react';
import * as api from '../../api'
import * as storage from '../../util/storage'
import { LoadingState } from './graph-util'
import TopStats from './top-stats';
import { IntervalPicker, getCurrentInterval } from './interval-picker'
import StatsExport from './stats-export'
import WithImportedSwitch from './with-imported-switch';
import SamplingNotice from './sampling-notice';
import FadeIn from '../../fade-in';
import * as url from '../../util/url'
import { isComparisonEnabled } from '../../comparison-input'
import LineGraphWithRouter from './line-graph'

function fetchTopStats(site, query) {
  const q = { ...query }

  if (!isComparisonEnabled(q.comparison)) {
    q.comparison = 'previous_period'
  }

  return api.get(url.apiPath(site, '/top-stats'), q)
}

function fetchMainGraph(site, query, metric, interval) {
  const params = {metric, interval}
  return api.get(url.apiPath(site, '/main-graph'), query, params)
}

export default function VisitorGraph(props) {
  const {site, query, lastLoadTimestamp} = props
  const isRealtime = query.period === 'realtime'
  const isDarkTheme = document.querySelector('html').classList.contains('dark') || false

  const topStatsBoundary = useRef(null)

  const [loading, setLoading] = useState(LoadingState.loading)
  const [topStatData, setTopStatData] = useState(null)
  const [graphData, setGraphData] = useState(null)

  const onIntervalUpdate = useCallback((newInterval) => {
    setGraphData(null)
    setLoading(LoadingState.updatingGraph)
    fetchGraphData(getStoredMetric(), newInterval)
  }, [query])

  const onMetricUpdate = useCallback((newMetric) => {
    setGraphData(null)
    setLoading(LoadingState.updatingGraph)
    fetchGraphData(newMetric, getCurrentInterval(site, query))
  }, [query])

  useEffect(() => {
    setTopStatData(null)
    setGraphData(null)
    setLoading(LoadingState.loading)
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
    fetchTopStats(site, query)
      .then((res) => {
        setTopStatData(res)

        let metric = getStoredMetric()
        const availableMetrics = res.top_stats.filter(stat => !!stat.graph_metric).map(stat => stat.graph_metric)

        if (!availableMetrics.includes(metric)) {
          metric = availableMetrics[0]
          storage.setItem(`metric__${site.domain}`, metric)
        }

        const interval = getCurrentInterval(site, query)

        fetchGraphData(metric, interval)
      })
  }

  function fetchGraphData(metric, interval) {
    fetchMainGraph(site, query, metric, interval)
      .then((res) => {
        setGraphData({...res, metric})
        setLoading(LoadingState.loaded)
      })
  }

  function getStoredMetric() {
    return storage.getItem(`metric__${site.domain}`)
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
      {loading === LoadingState.loading && renderLoader()}
      <FadeIn show={loading !== LoadingState.loading}>
        <div id="top-stats-container" className="flex flex-wrap" ref={topStatsBoundary} style={{ height: getTopStatsHeight() }}>
          <TopStats site={site} query={query} data={topStatData} onMetricUpdate={onMetricUpdate} tooltipBoundary={topStatsBoundary.current} lastLoadTimestamp={lastLoadTimestamp} />
        </div>
        <div className="relative px-2">
          {loading === LoadingState.updatingGraph && renderLoader()}
          <div className="absolute right-4 -top-8 py-1 flex items-center">
            {!isRealtime && <StatsExport site={site} query={query} />}
            <SamplingNotice samplePercent={topStatData}/>
            <WithImportedSwitch site={site} topStatData={topStatData} />
            <IntervalPicker site={site} query={query} onIntervalUpdate={onIntervalUpdate} />
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
