import React from 'react';
import { Link } from 'react-router-dom'
import * as api from '../../api'
import * as storage from '../../util/storage'
import LazyLoader from '../../components/lazy-loader'
import { METRIC_MAPPING, LoadingState } from './graph-util'
import TopStats from './top-stats';
import { IntervalPicker, getCurrentInterval } from './interval-picker';
import FadeIn from '../../fade-in';
import * as url from '../../util/url'
import { parseNaiveDate, isBefore } from '../../util/date'
import { isComparisonEnabled } from '../../comparison-input'
import LineGraphWithRouter from './line-graph'

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      topStatsLoadingState: LoadingState.loading,
      mainGraphLoadingState: LoadingState.loading,
      metric: storage.getItem(`metric__${this.props.site.domain}`) || 'visitors',
      exported: false
    }
    this.onVisible = this.onVisible.bind(this)
    this.updateMetric = this.updateMetric.bind(this)
    this.fetchTopStatData = this.fetchTopStatData.bind(this)
    this.fetchGraphData = this.fetchGraphData.bind(this)
    this.onIntervalUpdate = this.onIntervalUpdate.bind(this)
    this.boundary = React.createRef()
  }

  onIntervalUpdate(interval) {
    this.setState({ mainGraphLoadingState: LoadingState.refreshing, graphData: null }, () => this.fetchGraphData(interval))
  }

  onVisible() {
    this.setState({ mainGraphLoadingState: LoadingState.loading }, this.fetchGraphData)
    this.fetchTopStatData()
    if (this.props.query.period === 'realtime') {
      document.addEventListener('tick', this.fetchGraphData)
      document.addEventListener('tick', this.fetchTopStatData)
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const { metric } = this.state;
    const { query } = this.props

    if (query !== prevProps.query) {
      this.setState({ mainGraphLoadingState: LoadingState.loading, topStatsLoadingState: LoadingState.loading, graphData: null, topStatData: null }, this.fetchGraphData)
      this.fetchTopStatData()
    }

    if (metric !== prevState.metric) {
      this.setState({ mainGraphLoadingState: LoadingState.refreshing }, this.fetchGraphData)
    }
  }

  resetMetric() {
    const { topStatData } = this.state
    const { query, site } = this.props

    const savedMetric = storage.getItem(`metric__${site.domain}`)
    const selectableMetrics = topStatData && topStatData.top_stats.map(({ name }) => METRIC_MAPPING[name]).filter(name => name)
    const canSelectSavedMetric = selectableMetrics && selectableMetrics.includes(savedMetric)

    if (query.filters.goal && !['conversion_rate', 'events'].includes(savedMetric)) {
      this.setState({ metric: 'conversions' })
    } else if (canSelectSavedMetric) {
      this.setState({ metric: savedMetric })
    } else {
      this.setState({ metric: 'visitors' })
    }
  }

  componentWillUnmount() {
    document.removeEventListener('tick', this.fetchGraphData)
    document.removeEventListener('tick', this.fetchTopStatData)
  }

  storeTopStatsContainerHeight() {
    storage.setItem(`topStatsHeight__${this.props.site.domain}`, document.getElementById('top-stats-container').clientHeight)
  }

  updateMetric(clickedMetric) {
    if (this.state.metric == clickedMetric) return

    storage.setItem(`metric__${this.props.site.domain}`, clickedMetric)
    this.setState({ metric: clickedMetric, graphData: null })
  }

  fetchGraphData(interval) {
    const { site, query } = this.props
    const url = `/api/stats/${encodeURIComponent(site.domain)}/main-graph`
    const params = {
      metric: this.state.metric,
      interval: interval || getCurrentInterval(site, query)
    }

    api.get(url, this.props.query, params)
      .then((res) => {
        this.setState({ mainGraphLoadingState: LoadingState.loaded, graphData: res })
        return res
      })
      .catch((err) => {
        console.log(err)
        this.setState({ mainGraphLoadingState: LoadingState.loaded, graphData: false })
      })
  }

  fetchTopStatData() {
    const query = { ...this.props.query }
    if (!isComparisonEnabled(query.comparison)) query.comparison = 'previous_period'

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/top-stats`, query)
      .then((res) => {
        this.setState({ topStatsLoadingState: LoadingState.loaded, topStatData: res }, () => {
          this.storeTopStatsContainerHeight()
          this.resetMetric()
        })
        return res
      })
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

  renderInner() {
    const { query, site } = this.props;
    const { graphData, metric, topStatData, topStatsLoadingState, mainGraphLoadingState } = this.state;

    const isDarkTheme = document.querySelector('html').classList.contains('dark') || false

    const mainGraphRefreshing = (mainGraphLoadingState === LoadingState.refreshing)
    const topStatAndGraphLoaded = !!(topStatData && graphData)

    const shouldShow =
      topStatsLoadingState === LoadingState.loaded &&
      LoadingState.isLoadedOrRefreshing(mainGraphLoadingState) &&
      (topStatData && mainGraphRefreshing || topStatAndGraphLoaded)

    return (
      <FadeIn show={shouldShow}>
        <div id="top-stats-container" className="flex flex-wrap" ref={this.boundary} style={{ height: this.getTopStatsHeight() }}>
          <TopStats site={site} query={query} metric={metric} updateMetric={this.updateMetric} topStatData={topStatData} tooltipBoundary={this.boundary.current} lastLoadTimestamp={this.props.lastLoadTimestamp} />
        </div>
        <div className="relative px-2">
          {mainGraphRefreshing && renderLoader()}
          <div className="absolute right-4 -top-8 py-1 flex items-center">
            {this.downloadLink()}
            {this.samplingNotice()}
            {this.importedNotice()}
            <IntervalPicker site={site} query={query} onIntervalUpdate={this.onIntervalUpdate} />
          </div>
          <LineGraphWithRouter graphData={graphData} darkTheme={isDarkTheme} query={query} metric={metric}/>
        </div>
      </FadeIn>
    )
  }

  render() {
    const { mainGraphLoadingState, topStatsLoadingState } = this.state

    const showLoader =
      [mainGraphLoadingState, topStatsLoadingState].includes(LoadingState.loading) &&
      mainGraphLoadingState !== LoadingState.refreshing

    return (
      <LazyLoader onVisible={this.onVisible}>
        <div className={"relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825"}>
          {showLoader && renderLoader()}
          {this.renderInner()}
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
