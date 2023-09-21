import React from 'react';
import { withRouter, Link } from 'react-router-dom'
import Chart from 'chart.js/auto';
import { navigateToQuery } from '../../query'
import * as api from '../../api'
import * as storage from '../../util/storage'
import LazyLoader from '../../components/lazy-loader'
import GraphTooltip from './graph-tooltip'
import { buildDataSet, METRIC_MAPPING, METRIC_LABELS, METRIC_FORMATTER, LoadingState } from './graph-util'
import dateFormatter from './date-formatter';
import TopStats from './top-stats';
import { IntervalPicker, getStoredInterval, storeInterval } from './interval-picker';
import FadeIn from '../../fade-in';
import * as url from '../../util/url'
import classNames from 'classnames';
import { monthsBetweenDates, parseNaiveDate, isBefore } from '../../util/date'
import { isComparisonEnabled } from '../../comparison-input'

const calculateMaximumY = function(dataset) {
  const yAxisValues = dataset
    .flatMap((item) => item.data)
    .map((item) => item || 0)

  if (yAxisValues) {
    return Math.max(...yAxisValues)
  } else {
    return 1
  }
}

class LineGraph extends React.Component {
  constructor(props) {
    super(props);
    this.boundary = React.createRef()
    this.regenerateChart = this.regenerateChart.bind(this);
    this.updateWindowDimensions = this.updateWindowDimensions.bind(this);
    this.state = {
      exported: false
    };
  }

  regenerateChart() {
    const { graphData, metric, query } = this.props
    const graphEl = document.getElementById("main-graph-canvas")
    this.ctx = graphEl.getContext('2d');
    const dataSet = buildDataSet(graphData.plot, graphData.comparison_plot, graphData.present_index, this.ctx, METRIC_LABELS[metric])

    return new Chart(this.ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: dataSet
      },
      options: {
        animation: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: false,
            mode: 'index',
            intersect: false,
            position: 'average',
            external: GraphTooltip(graphData, metric, query)
          },
        },
        responsive: true,
        maintainAspectRatio: false,
        onResize: this.updateWindowDimensions,
        elements: { line: { tension: 0 }, point: { radius: 0 } },
        onClick: this.onClick.bind(this),
        scale: {
          ticks: { precision: 0, maxTicksLimit: 8 }
        },
        scales: {
          y: {
            min: 0,
            suggestedMax: calculateMaximumY(dataSet),
            ticks: {
              callback: METRIC_FORMATTER[metric],
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            },
            grid: {
              zeroLineColor: 'transparent',
              drawBorder: false,
            }
          },
          yComparison: {
            min: 0,
            suggestedMax: calculateMaximumY(dataSet),
            display: false,
            grid: { display: false },
          },
          x: {
            grid: { display: false },
            ticks: {
              callback: function(val, _index, _ticks) {
                if (this.getLabelForValue(val) == "__blank__") return ""

                const hasMultipleYears =
                  graphData.labels
                    .filter((date) => typeof date === 'string')
                    .map(date => date.split('-')[0])
                    .filter((value, index, list) => list.indexOf(value) === index)
                    .length > 1

                if (graphData.interval === 'hour' && query.period !== 'day') {
                  const date = dateFormatter({
                    interval: "date",
                    longForm: false,
                    period: query.period,
                    shouldShowYear: hasMultipleYears,
                  })(this.getLabelForValue(val))

                  const hour = dateFormatter({
                    interval: graphData.interval,
                    longForm: false,
                    period: query.period,
                    shouldShowYear: hasMultipleYears,
                  })(this.getLabelForValue(val))

                  // Returns a combination of date and hour. This is because
                  // small intervals like hour may return multiple days
                  // depending on the query period.
                  return `${date}, ${hour}`
                }

                if (graphData.interval === 'minute' && query.period !== 'realtime') {
                  return dateFormatter({
                    interval: "hour", longForm: false, period: query.period,
                  })(this.getLabelForValue(val))
                }

                return dateFormatter({
                  interval: graphData.interval, longForm: false, period: query.period, shouldShowYear: hasMultipleYears,
                })(this.getLabelForValue(val))
              },
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            }
          }
        },
        interaction: {
          mode: 'index',
          intersect: false,
        }
      }
    });
  }

  repositionTooltip(e) {
    const tooltipEl = document.getElementById('chartjs-tooltip');
    if (tooltipEl && window.innerWidth >= 768) {
      if (e.clientX > 0.66 * window.innerWidth) {
        tooltipEl.style.right = (window.innerWidth - e.clientX) + window.pageXOffset + 'px'
        tooltipEl.style.left = null;
      } else {
        tooltipEl.style.right = null;
        tooltipEl.style.left = e.clientX + window.pageXOffset + 'px'
      }
      tooltipEl.style.top = e.clientY + window.pageYOffset + 'px'
      tooltipEl.style.opacity = 1;
    }
  }

  componentDidMount() {
    if (this.props.graphData) {
      this.chart = this.regenerateChart();
    }
    window.addEventListener('mousemove', this.repositionTooltip);
  }

  componentDidUpdate(prevProps) {
    const { graphData, darkTheme } = this.props;
    const tooltip = document.getElementById('chartjs-tooltip');

    if (
      graphData !== prevProps.graphData ||
      darkTheme !== prevProps.darkTheme
    ) {

      if (graphData) {
        if (this.chart) {
          this.chart.destroy();
        }
        this.chart = this.regenerateChart();
        this.chart.update();
      }

      if (tooltip) {
        tooltip.style.display = 'none';
      }
    }

    if (!graphData) {
      if (this.chart) {
        this.chart.destroy();
      }

      if (tooltip) {
        tooltip.style.display = 'none';
      }
    }
  }

  componentWillUnmount() {
    // Ensure that the tooltip doesn't hang around when we are loading more data
    const tooltip = document.getElementById('chartjs-tooltip');
    if (tooltip) {
      tooltip.style.opacity = 0;
      tooltip.style.display = 'none';
    }
    window.removeEventListener('mousemove', this.repositionTooltip)
  }

  /**
   * The current ticks' limits are set to treat iPad (regular/Mini/Pro) as a regular screen.
   * @param {*} chart - The chart instance.
   * @param {*} dimensions - An object containing the new dimensions *of the chart.*
   */
  updateWindowDimensions(chart, dimensions) {
    chart.options.scales.x.ticks.maxTicksLimit = dimensions.width < 720 ? 5 : 8
  }

  onClick(e) {
    const element = this.chart.getElementsAtEventForMode(e, 'index', { intersect: false })[0]
    const date = this.props.graphData.labels[element.index] || this.props.graphData.comparison_labels[element.index]

    if (this.props.graphData.interval === 'month') {
      navigateToQuery(this.props.history, this.props.query, { period: 'month', date })
    } else if (this.props.graphData.interval === 'date') {
      navigateToQuery(this.props.history, this.props.query, { period: 'day', date })
    }
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
        const interval = this.props.graphData?.interval
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
    const samplePercent = this.props.topStatData && this.props.topStatData.sample_percent

    if (samplePercent < 100) {
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
    if (!this.props.topStatData?.imported_source) return

    const isBeforeNativeStats = (date) => {
      if (!date) return false

      const nativeStatsBegin = parseNaiveDate(this.props.site.nativeStatsBegin)
      const parsedDate = parseNaiveDate(date)

      return isBefore(parsedDate, nativeStatsBegin, "day")
    }

    const isQueryingImportedPeriod = isBeforeNativeStats(this.props.topStatData.from)
    const isComparingImportedPeriod = isBeforeNativeStats(this.props.topStatData.comparing_from)

    if (isQueryingImportedPeriod || isComparingImportedPeriod) {
      const source = this.props.topStatData.imported_source
      const withImported = this.props.topStatData.with_imported;
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
    if (this.props.topStatData) {
      return 'auto'
    } else {
      return `${storage.getItem(`topStatsHeight__${this.props.site.domain}`) || 89}px`
    }
  }

  render() {
    const { mainGraphRefreshing, updateMetric, updateInterval, metric, topStatData, query, site, graphData, lastLoadTimestamp } = this.props
    const canvasClass = classNames('mt-4 select-none', { 'cursor-pointer': !['minute', 'hour'].includes(graphData?.interval) })

    return (
      <div>
        <div id="top-stats-container" className="flex flex-wrap" ref={this.boundary} style={{ height: this.getTopStatsHeight() }}>
          <TopStats site={site} query={query} metric={metric} updateMetric={updateMetric} topStatData={topStatData} tooltipBoundary={this.boundary.current} lastLoadTimestamp={lastLoadTimestamp} />
        </div>
        <div className="relative px-2">
          {mainGraphRefreshing && renderLoader()}
          <div className="absolute right-4 -top-8 py-1 flex items-center">
            {this.downloadLink()}
            {this.samplingNotice()}
            {this.importedNotice()}
            <IntervalPicker site={site} query={query} graphData={graphData} metric={metric} updateInterval={updateInterval} />
          </div>
          <FadeIn show={graphData}>
            <div className="relative h-96 w-full z-0">
              <canvas id="main-graph-canvas" className={canvasClass}></canvas>
            </div>
          </FadeIn>
        </div>
      </div>
    )
  }
}

const LineGraphWithRouter = withRouter(LineGraph)

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      topStatsLoadingState: LoadingState.loading,
      mainGraphLoadingState: LoadingState.loading,
      metric: storage.getItem(`metric__${this.props.site.domain}`) || 'visitors'
    }
    this.onVisible = this.onVisible.bind(this)
    this.updateMetric = this.updateMetric.bind(this)
    this.fetchTopStatData = this.fetchTopStatData.bind(this)
    this.fetchGraphData = this.fetchGraphData.bind(this)
    this.updateInterval = this.updateInterval.bind(this)
  }

  isIntervalValid(interval) {
    const { query, site } = this.props
    const validIntervals = site.validIntervalsByPeriod[query.period] || []

    return validIntervals.includes(interval)
  }

  getIntervalFromStorage() {
    const { query, site } = this.props
    let interval = getStoredInterval(query.period, site.domain)

    if (interval !== "week" && interval !== "month" && query.period === "custom" && monthsBetweenDates(query.from, query.to) > 12) {
      interval = "month"
    }

    if (this.isIntervalValid(interval)) {
      return interval
    } else {
      return null
    }
  }

  updateInterval(interval) {
    if (this.isIntervalValid(interval)) {
      storeInterval(this.props.query.period, this.props.site.domain, interval)
      this.setState({ mainGraphLoadingState: LoadingState.refreshing, graphData: null }, this.fetchGraphData)
    }
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

    if (query.filters.goal) {
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

  fetchGraphData() {
    const url = `/api/stats/${encodeURIComponent(this.props.site.domain)}/main-graph`
    let params = { metric: this.state.metric }
    const interval = this.getIntervalFromStorage()
    if (interval) { params.interval = interval }

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

  renderInner() {
    const { query, site } = this.props;
    const { graphData, metric, topStatData, topStatsLoadingState, mainGraphLoadingState } = this.state;

    const theme = document.querySelector('html').classList.contains('dark') || false

    const mainGraphRefreshing = (mainGraphLoadingState === LoadingState.refreshing)
    const topStatAndGraphLoaded = !!(topStatData && graphData)

    const shouldShow =
      topStatsLoadingState === LoadingState.loaded &&
      LoadingState.isLoadedOrRefreshing(mainGraphLoadingState) &&
      (topStatData && mainGraphRefreshing || topStatAndGraphLoaded)

    return (
      <FadeIn show={shouldShow}>
        <LineGraphWithRouter mainGraphRefreshing={mainGraphRefreshing} graphData={graphData} topStatData={topStatData} site={site} query={query} darkTheme={theme} metric={metric} updateMetric={this.updateMetric} updateInterval={this.updateInterval} lastLoadTimestamp={this.props.lastLoadTimestamp} />
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
