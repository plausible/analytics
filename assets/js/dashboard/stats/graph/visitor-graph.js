import React from 'react';
import { Link } from 'react-router-dom'
import * as api from '../../api'
import * as storage from '../../util/storage'
import LazyLoader from '../../components/lazy-loader'
import { LoadingState } from './graph-util'
import TopStats from './top-stats';
import { IntervalPicker, getCurrentInterval } from './interval-picker';
import FadeIn from '../../fade-in';
import * as url from '../../util/url'
import { parseNaiveDate, isBefore } from '../../util/date'
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
      exported: false
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
  
  pollExportReady() {
    if (document.cookie.includes('exporting')) {
      setTimeout(this.pollExportReady.bind(this), 1000);
    } else {
      this.setState({ exported: false })
    }
  }

  downloadSpinner() {
    this.setState({ exported: true });
    document.cookie = "exporting=";
    setTimeout(this.pollExportReady.bind(this), 1000);
  }

  downloadLink() {
    if (this.props.query.period !== 'realtime') {

      if (this.state.exported) {
        return (
          <div className="w-4 h-4 mx-2">
            <svg className="animate-spin h-4 w-4 text-indigo-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        )
      } else {
        const interval = this.state.graphData?.interval
        const queryParams = api.serializeQuery(this.props.query, [{ interval }])
        const endpoint = `/${encodeURIComponent(this.props.site.domain)}/export${queryParams}`

        return (
          <a className="w-4 h-4 mx-2" href={endpoint} download onClick={this.downloadSpinner.bind(this)}>
            <svg className="absolute text-gray-700 feather dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
          </a>
        )
      }
    }
  }

  samplingNotice() {
    const samplePercent = this.state.topStatData?.sample_percent

    if (samplePercent && samplePercent < 100) {
      return (
        <div tooltip={`Stats based on a ${samplePercent}% sample of all visitors`} className="cursor-pointer w-4 h-4 mx-2">
          <svg className="absolute w-4 h-4 dark:text-gray-300 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
      )
    }
  }

  importedNotice() {
    const { topStatData } = this.state

    if (!topStatData?.imported_source) return

    const isBeforeNativeStats = (date) => {
      if (!date) return false

      const nativeStatsBegin = parseNaiveDate(this.props.site.nativeStatsBegin)
      const parsedDate = parseNaiveDate(date)

      return isBefore(parsedDate, nativeStatsBegin, "day")
    }

    const isQueryingImportedPeriod = isBeforeNativeStats(topStatData.from)
    const isComparingImportedPeriod = isBeforeNativeStats(topStatData.comparing_from)

    if (isQueryingImportedPeriod || isComparingImportedPeriod) {
      const source = topStatData.imported_source
      const withImported = topStatData.with_imported;
      const strike = withImported ? "" : " line-through"
      const target = url.setQuery('with_imported', !withImported)
      const tip = withImported ? "" : "do not ";

      return (
        <Link to={target} className="w-4 h-4 mx-2">
          <div tooltip={`Stats ${tip}include data imported from ${source}.`} className="cursor-pointer w-4 h-4">
            <svg className="absolute dark:text-gray-300 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <text x="4" y="18" fontSize="24" fill="currentColor" className={"text-gray-700 dark:text-gray-300" + strike}>{source[0].toUpperCase()}</text>
            </svg>
          </div>
        </Link>
      )
    }
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
                {this.downloadLink()}
                {this.samplingNotice()}
                {this.importedNotice()}
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
