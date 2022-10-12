import React from 'react';
import { withRouter, Link } from 'react-router-dom'
import Chart from 'chart.js/auto';
import { navigateToQuery } from '../../query'
import * as api from '../../api'
import * as storage from '../../util/storage'
import LazyLoader from '../../components/lazy-loader'
import {GraphTooltip, buildDataSet, dateFormatter, INTERVALS, METRIC_MAPPING, METRIC_LABELS, METRIC_FORMATTER} from './graph-util';
import TopStats from './top-stats';
import IntervalPicker, {INTERVAL_MAPPING} from './interval-picker';
import FadeIn from '../../fade-in';
import * as url from '../../util/url'

class LineGraph extends React.Component {
  constructor(props) {
    super(props);
    this.boundary = React.createRef()
    this.regenerateChart = this.regenerateChart.bind(this);
    this.updateWindowDimensions =  this.updateWindowDimensions.bind(this);
    this.state = {
      exported: false
    };
  }

  regenerateChart() {
    const { graphData, metric, query } = this.props
    const graphEl = document.getElementById("main-graph-canvas")
    this.ctx = graphEl.getContext('2d');
    const dataSet = buildDataSet(graphData.plot, graphData.present_index, this.ctx, METRIC_LABELS[metric])
    // const prev_dataSet = graphData.prev_plot && buildDataSet(graphData.prev_plot, false, this.ctx, METRIC_LABELS[metric], true)
    // const combinedDataSets = comparison.enabled && prev_dataSet ? [...dataSet, ...prev_dataSet] : dataSet;

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
        onResize: this.updateWindowDimensions,
        elements: { line: { tension: 0 }, point: { radius: 0 } },
        onClick: this.onClick.bind(this),
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: METRIC_FORMATTER[metric],
              maxTicksLimit: 8,
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            },
            grid: {
              zeroLineColor: 'transparent',
              drawBorder: false,
            }
          },
          x: {
            grid: { display: false },
            ticks: {
              maxTicksLimit: 8,
              callback: function (val, _index, _ticks) {
                if (graphData.interval === 'hour' && query.period !== 'day') {
                  return `${dateFormatter("date", false, query.period)(this.getLabelForValue(val))}, ${dateFormatter(graphData.interval, false, query.period)(this.getLabelForValue(val))}`
                }

                if (graphData.interval === 'minute' && query.period !== 'realtime') {
                  return dateFormatter("hour", false, query.period)(this.getLabelForValue(val))
                }

                return dateFormatter(graphData.interval, false, query.period)(this.getLabelForValue(val))
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
    if (this.props.metric && this.props.graphData) {
      this.chart = this.regenerateChart();
    }
    window.addEventListener('mousemove', this.repositionTooltip);
  }

  componentDidUpdate(prevProps) {
    const { graphData, metric, darkTheme } = this.props;
    const tooltip = document.getElementById('chartjs-tooltip');

    if (
      graphData !== prevProps.graphData ||
      darkTheme !== prevProps.darkTheme
    ) {

      if (metric && graphData) {
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

    if (!graphData || !metric) {
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
    chart.options.scales.y.ticks.maxTicksLimit = dimensions.height < 233 ? 3 : 8
  }

  onClick(e) {
    const element = this.chart.getElementsAtEventForMode(e, 'index', { intersect: false })[0]
    const date = this.chart.data.labels[element.index]

    if (this.props.graphData.interval === 'month') {
      navigateToQuery(
        this.props.history,
        this.props.query,
        {
          period: 'month',
          date,
        }
      )
    } else if (this.props.graphData.interval === 'date') {
      navigateToQuery(
        this.props.history,
        this.props.query,
        {
          period: 'day',
          date,
        }
      )
    }
  }

  pollExportReady() {
    if (document.cookie.includes('exporting')) {
      setTimeout(this.pollExportReady.bind(this), 1000);
    } else {
      this.setState({exported: false})
    }
  }

  downloadSpinner() {
    this.setState({exported: true});
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
        const endpoint = `/${encodeURIComponent(this.props.site.domain)}/export${api.serializeQuery(this.props.query)}`

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
    const source = this.props.topStatData && this.props.topStatData.imported_source;

    if (source) {
      const withImported = this.props.topStatData.with_imported;
      const strike = withImported ? "" : " line-through"
      const target =  url.setQuery('with_imported', !withImported)
      const tip = withImported ? "" : "do not ";

      return (
        <Link to={target} className="w-4 h-4 mx-2">
          <div tooltip={`Stats ${tip}include data imported from ${source}.`} className="cursor-pointer w-4 h-4">
            <svg className="absolute dark:text-gray-300 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <text x="4" y="18" fontSize="24" fill="currentColor" className={"text-gray-700 dark:text-gray-300" + strike}>{ source[0].toUpperCase() }</text>
            </svg>
          </div>
        </Link>
      )
    }
  }

  render() {
    const { updateMetric, metric, topStatData, query, site, graphData } = this.props
    const extraClass = this.props.graphData && this.props.graphData.interval === 'hour' ? '' : 'cursor-pointer'

    return (
      <div className="graph-inner">
        <FadeIn show={topStatData}>
          <div className="flex flex-wrap">
            {topStatData && <TopStats query={query} metric={metric} updateMetric={updateMetric} topStatData={topStatData}/>}
          </div>
        </FadeIn>
        <div className="relative px-2">
          <div className="absolute right-4 -top-10 flex">
            <IntervalPicker site={site} query={query} graphData={graphData} metric={metric} updateInterval={this.props.updateInterval}/>
            { this.downloadLink() }
            { this.samplingNotice() }
            { this.importedNotice() }
          </div>
          <FadeIn show={graphData}>
            <canvas id="main-graph-canvas" className={'mt-4 select-none ' + extraClass} width="1054" height="342"></canvas>
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
      loadingTopStats: true,
      loadingMainGraph: true,
      metric: storage.getItem(`metric__${this.props.site.domain}`) || 'visitors',
      interval: storage.getItem(`interval__${this.props.query.period}__${this.props.site.domain}`)
    }
    this.onVisible = this.onVisible.bind(this)
    this.updateMetric = this.updateMetric.bind(this)
    this.fetchTopStatData = this.fetchTopStatData.bind(this)
    this.fetchGraphData = this.fetchGraphData.bind(this)
    this.validateInterval = this.validateInterval.bind(this)
    this.updateInterval = this.updateInterval.bind(this)
  }

  validateInterval() {
    const period = this.props.query && this.props.query.period
    const interval = storage.getItem(`interval__${period}__${this.props.site.domain}`)
    const outOfRangeInterval = period !== 'custom' && !INTERVAL_MAPPING[period].includes(interval);

    if (!interval || !INTERVALS.includes(interval) || outOfRangeInterval) {
      this.setState({interval: undefined}, () => {
        this.setState({graphData: null})
        this.fetchGraphData()
      })
    } else {
      this.setState({graphData: null, interval}, () => {
        this.fetchGraphData()
      })
    }
  }

  updateInterval(interval) {
    if (INTERVALS.includes(interval)) {
      this.setState({interval, loadingMainGraph: 2}, this.validateInterval)
      storage.setItem(`interval__${this.props.query.period}__${this.props.site.domain}`, interval)
    }
  }

  onVisible() {
    this.setState({loadingMainGraph: true}, this.validateInterval)
    this.fetchTopStatData()
    if (this.props.timer) {
      this.props.timer.onTick(this.validateInterval)
      this.props.timer.onTick(this.fetchTopStatData)
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const { metric, topStatData, interval } = this.state;

    if (this.props.query !== prevProps.query) {
      if (metric) {
        this.setState({ loadingMainGraph: true, loadingTopStats: true, graphData: null, topStatData: null }, this.validateInterval)
      } else {
        this.setState({ loadingTopStats: true, topStatData: null })
      }
      this.fetchTopStatData()
    }

    if (metric !== prevState.metric) {
      this.setState({loadingMainGraph: 2}, this.validateInterval)
    }

    if (interval !== prevState.interval && interval) {
      this.setState({loadingMainGraph: 2}, this.validateInterval)
    }

    const savedMetric = storage.getItem(`metric__${this.props.site.domain}`)
    const topStatLabels = topStatData && topStatData.top_stats.map(({ name }) => METRIC_MAPPING[name]).filter(name => name)
    const prevTopStatLabels = prevState.topStatData && prevState.topStatData.top_stats.map(({ name }) => METRIC_MAPPING[name]).filter(name => name)
    if (topStatLabels && `${topStatLabels}` !== `${prevTopStatLabels}`) {
      if (this.props.query.filters.goal && metric !== 'conversions') {
        this.setState({ metric: 'conversions' })
      } else if (topStatLabels.includes(savedMetric) && savedMetric !== "") {
        this.setState({ metric: savedMetric })
      } else {
        this.setState({ metric: topStatLabels[0] })
      }
    }
  }

  updateMetric(newMetric) {
    if (newMetric === this.state.metric) {
      storage.setItem(`metric__${this.props.site.domain}`, "")
      this.setState({ metric: "" })
    } else {
      storage.setItem(`metric__${this.props.site.domain}`, newMetric)
      this.setState({ metric: newMetric })
    }
  }

  fetchGraphData() {
    if (this.state.metric) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/main-graph`, this.props.query, {metric: this.state.metric || 'none', interval: this.state.interval})
      .then((res) => {
        this.setState({ loadingMainGraph: false, graphData: res })
        return res
      })
      .catch((err) => {
        console.log(err)
        this.setState({ loadingMainGraph: false, graphData: false })
      })
    } else {
      this.setState({ loadingMainGraph: false, graphData: null })
    }
  }

  fetchTopStatData() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/top-stats`, this.props.query)
      .then((res) => {
        this.setState({ loadingTopStats: false, topStatData: res })
        return res
      })
    }

  renderInner() {
    const { query, site } = this.props;
    const { graphData, metric, topStatData, loadingTopStats, loadingMainGraph } = this.state;

    const theme = document.querySelector('html').classList.contains('dark') || false

    return (
      <FadeIn show={(!loadingTopStats && (!loadingMainGraph || loadingMainGraph === 2) && (topStatData && (!metric || loadingMainGraph === 2) || !!(topStatData && graphData)))}>
        <LineGraphWithRouter graphData={graphData} topStatData={topStatData} site={site} query={query} darkTheme={theme} metric={metric} updateMetric={this.updateMetric} updateInterval={this.updateInterval}/>
      </FadeIn>
    )
  }

  render() {
    const {metric, loadingMainGraph, loadingTopStats} = this.state

    return (
      <LazyLoader onVisible={this.onVisible}>
        <div className={`relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825 transition-padding ease-in-out duration-150 ${metric ? 'main-graph' : 'top-stats-only'}`}>
          {(loadingMainGraph || loadingTopStats) && <div className="graph-inner"><div className={`${loadingMainGraph === 2 ? 'pt-52 sm:pt-56 md:pt-60' : (!metric) ? 'pt-16 sm:pt-14 md:pt-18 lg:pt-5' : 'pt-32 sm:pt-36 md:pt-48'} mx-auto loading`}><div></div></div></div>}
          {this.renderInner()}
        </div>
      </LazyLoader>
    )
  }
}
