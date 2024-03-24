import React from 'react';
import * as api from '../../api'
import * as storage from '../../util/storage'
import LazyLoader from '../../components/lazy-loader'
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

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: LoadingState.loading,
      topStatData: null,
      graphData: null,
    }
    this.onVisible = this.onVisible.bind(this)
    this.fetchTopStatsAndGraphData = this.fetchTopStatsAndGraphData.bind(this)
    this.fetchGraphData = this.fetchGraphData.bind(this)
    this.onIntervalUpdate = this.onIntervalUpdate.bind(this)
    this.onMetricUpdate = this.onMetricUpdate.bind(this)
    this.boundary = React.createRef()
  }

  fetchTopStatsAndGraphData() {
    const { site, query } = this.props
    
    this.setState({loading: LoadingState.loading, topStatData: null, graphData: null})

    fetchTopStats(site, query)
      .then((res) => {
        this.setState({ topStatData: res, loading: LoadingState.updatingGraph }, () => {
          this.storeTopStatsContainerHeight()
        })
        
        let metric = this.getStoredMetric()
        const availableMetrics = res.top_stats.filter(stat => !!stat.graph_metric).map(stat => stat.graph_metric)
        
        if (!availableMetrics.includes(metric)) {
          metric = availableMetrics[0]
          storage.setItem(`metric__${this.props.site.domain}`, metric)
        }

        const interval = getCurrentInterval(site, query)

        return fetchMainGraph(site, query, metric, interval)
      })
      .then((res) => {
        this.setState({ graphData: res, loading: LoadingState.loaded })
      })
  }

  fetchGraphData(metric, interval) {
    const { site, query } = this.props
    
    this.setState({loading: LoadingState.updatingGraph, graphData: null})

    fetchMainGraph(site, query, metric, interval)
      .then((res) => {
        this.setState({graphData: res, loading: LoadingState.loaded})
      })
  }

  getStoredMetric() {
    return storage.getItem(`metric__${this.props.site.domain}`)
  }

  onIntervalUpdate(newInterval) {
    this.fetchGraphData(this.getStoredMetric(), newInterval)
  }

  onMetricUpdate(newMetric) {
    this.fetchGraphData(newMetric, getCurrentInterval(this.props.site, this.props.query))
  }

  onVisible() {
    this.fetchTopStatsAndGraphData()

    if (this.props.query.period === 'realtime') {
      document.addEventListener('tick', this.fetchTopStatsAndGraphData)
    }
  }

  componentDidUpdate(prevProps, prevState) {
    if (this.props.query !== prevProps.query) {
      this.fetchTopStatsAndGraphData()
    }
  }

  componentWillUnmount() {
    document.removeEventListener('tick', this.fetchTopStatsAndGraphData)
  }

  storeTopStatsContainerHeight() {
    storage.setItem(`topStatsHeight__${this.props.site.domain}`, document.getElementById('top-stats-container').clientHeight)
  }

  // This function is used for maintaining the main-graph/top-stats container height in the
  // loading process. The container height depends on how many top stat metrics are returned
  // from the API, but in the loading state, we don't know that yet. We can use localStorage
  // to keep track of the Top Stats container height.
  getTopStatsHeight() {
    if (this.state.topStatData) {
      return 'auto'
    } else {
      return `${storage.getItem(`topStatsHeight__${this.props.site.domain}`) || 89}px`
    }
  }

  render() {
    const { query, site } = this.props;
    const { graphData, topStatData, loading } = this.state;

    const isDarkTheme = document.querySelector('html').classList.contains('dark') || false
    const isRealtime = query.period === 'realtime'

    return (
      <LazyLoader onVisible={this.onVisible}>
        <div className={"relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825"}>
          {loading === LoadingState.loading && renderLoader()}
          <FadeIn show={loading !== LoadingState.loading}>
            <div id="top-stats-container" className="flex flex-wrap" ref={this.boundary} style={{ height: this.getTopStatsHeight() }}>
              <TopStats site={site} query={query} onMetricUpdate={this.onMetricUpdate} topStatData={topStatData} tooltipBoundary={this.boundary.current} lastLoadTimestamp={this.props.lastLoadTimestamp} />
            </div>
            <div className="relative px-2">
              {loading === LoadingState.updatingGraph && renderLoader()}
              <div className="absolute right-4 -top-8 py-1 flex items-center">
                {!isRealtime && <StatsExport site={site} query={query} />}
                <SamplingNotice samplePercent={topStatData}/>
                <WithImportedSwitch site={site} topStatData={topStatData} />
                <IntervalPicker site={site} query={query} onIntervalUpdate={this.onIntervalUpdate} />
              </div>
              <LineGraphWithRouter graphData={graphData} darkTheme={isDarkTheme} query={query} />
            </div>
          </FadeIn>
        </div>
      </LazyLoader>
    )
  }
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
