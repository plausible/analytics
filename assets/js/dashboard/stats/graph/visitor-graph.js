import React from 'react';
import { withRouter, Link } from 'react-router-dom'
import Chart from 'chart.js/auto';
import { navigateToQuery } from '../../query'
import numberFormatter, {durationFormatter} from '../../util/number-formatter'
import * as api from '../../api'
import * as storage from '../../util/storage'
import LazyLoader from '../../components/lazy-loader'
import {GraphTooltip, buildDataSet, dateFormatter} from './graph-util';
import TopStats from './top-stats';
import * as url from '../../util/url'

export const METRIC_MAPPING = {
  'Unique visitors (last 30 min)': 'visitors',
  'Pageviews (last 30 min)': 'pageviews',
  'Unique visitors': 'visitors',
  'Visit duration': 'visit_duration',
  'Total pageviews': 'pageviews',
  'Bounce rate': 'bounce_rate',
  'Unique conversions': 'conversions',
  // 'Time on Page': 'time',
  // 'Conversion rate': 'conversion_rate',
  // 'Total conversions': 't_conversions',
}

export const METRIC_LABELS = {
  'visitors': 'Visitors',
  'pageviews': 'Pageviews',
  'bounce_rate': 'Bounce Rate',
  'visit_duration': 'Visit Duration',
  'conversions': 'Converted Visitors',
  // 'time': 'Time on Page',
  // 'conversion_rate': 'Conversion Rate',
  // 't_conversions': 'Total Conversions'
}

export const METRIC_FORMATTER = {
  'visitors': numberFormatter,
  'pageviews': numberFormatter,
  'bounce_rate': (number) => (`${number}%`),
  'visit_duration': durationFormatter,
  'conversions': numberFormatter,
  // 'time': durationFormatter,
  // 'conversion_rate': (number) => (`${Math.max(number, 100)}%`),
  // 't_conversions': numberFormatter
}

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
    const { graphData, metric } = this.props
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
            external: GraphTooltip(graphData, metric)
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
              callback: function(val, _index, _ticks) { return dateFormatter(graphData.interval)(this.getLabelForValue(val)) },
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

    if (metric && graphData && (
      graphData !== prevProps.graphData ||
      darkTheme !== prevProps.darkTheme
    )) {
      if (this.chart) {
        this.chart.destroy();
      }
      this.chart = this.regenerateChart();
      this.chart.update();

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
            <svg className="absolute text-gray-700 feather dark:text-gray-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
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
    const source = this.props.topStatData.imported_source;

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
    const { updateMetric, metric, topStatData, query } = this.props
    const extraClass = this.props.graphData && this.props.graphData.interval === 'hour' ? '' : 'cursor-pointer'

    return (
      <div className="graph-inner">
        <div className="flex flex-wrap" ref={this.boundary}>
          <TopStats query={query} metric={metric} updateMetric={updateMetric} topStatData={topStatData} tooltipBoundary={this.boundary.current} />
        </div>
        <div className="relative px-2">
          <div className="absolute right-4 -top-10 flex">
            {this.downloadLink()}
            {this.samplingNotice()}
            { this.importedNotice() }
          </div>
          <canvas id="main-graph-canvas" className={'mt-4 select-none ' + extraClass} width="1054" height="342"></canvas>
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
      loading: 2,
      metric: storage.getItem(`metric__${this.props.site.domain}`) || 'visitors'
    }
    this.onVisible = this.onVisible.bind(this)
    this.updateMetric = this.updateMetric.bind(this)
    this.fetchTopStatData = this.fetchTopStatData.bind(this)
    this.fetchGraphData = this.fetchGraphData.bind(this)
  }

  onVisible() {
    this.fetchGraphData()
    this.fetchTopStatData()
    if (this.props.timer) {
      this.props.timer.onTick(this.fetchGraphData)
      this.props.timer.onTick(this.fetchTopStatData)
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const { metric, topStatData } = this.state;

    if (this.props.query !== prevProps.query) {
      this.setState({ loading: 3, graphData: null, topStatData: null })
      this.fetchGraphData()
      this.fetchTopStatData()
    }

    if (metric !== prevState.metric) {
      this.setState({loading: 1, graphData: null})
      this.fetchGraphData()
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
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/main-graph`, this.props.query, {metric: this.state.metric || 'none'})
      .then((res) => {
        this.setState((state) => ({ loading: state.loading-2, graphData: res }))
        return res
      })
    } else {
      this.setState((state) => ({ loading: state.loading-2, graphData: null }))
    }
  }

  fetchTopStatData() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/top-stats`, this.props.query)
      .then((res) => {
        this.setState((state) => ({ loading: state.loading-1, topStatData: res }))
        return res
      })
    }

  renderInner() {
    const { query, site } = this.props;
    const { graphData, metric, topStatData, loading } = this.state;

    const theme = document.querySelector('html').classList.contains('dark') || false

    if ((loading <= 1 && topStatData) || (topStatData && graphData)) {
      return (
          <LineGraphWithRouter graphData={graphData} topStatData={topStatData} site={site} query={query} darkTheme={theme} metric={metric} updateMetric={this.updateMetric} />
      )
    }
  }

  render() {
    const {metric, topStatData, graphData} = this.state

    return (
      <LazyLoader onVisible={this.onVisible}>
        <div className={`relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825 transition-padding ease-in-out duration-150 ${metric ? 'main-graph' : 'top-stats-only'}`}>
          {this.state.loading > 0 && <div className="graph-inner"><div className={`${topStatData && !graphData ? 'pt-52 sm:pt-56 md:pt-60' : metric ? 'pt-32 sm:pt-36 md:pt-48' : 'pt-16 sm:pt-14 md:pt-18 lg:pt-5'} mx-auto loading`}><div></div></div></div>}
          {this.renderInner()}
        </div>
      </LazyLoader>
    )
  }
}
