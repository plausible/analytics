import React from 'react';
import { withRouter } from 'react-router-dom'
import Chart from 'chart.js/auto';
import { eventName, navigateToQuery } from '../query'
import numberFormatter, { durationFormatter } from '../number-formatter'
import * as api from '../api'
import * as storage from '../storage'
import { ThemeContext } from '../theme-context'
import LazyLoader from '../lazy-loader'
import { withComparisonConsumer } from '../comparison-consumer-hoc'

function buildDataSet(plot, present_index, ctx, label, isPrevious) {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  var prev_gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');
  prev_gradient.addColorStop(0, 'rgba(101,116,205, 0.075)');
  prev_gradient.addColorStop(1, 'rgba(101,116,205, 0)');

  if (!isPrevious) {
    if (present_index) {
      var dashedPart = plot.slice(present_index - 1);
      var dashedPlot = (new Array(plot.length - dashedPart.length)).concat(dashedPart)
      const _plot = [...plot]
      for (var i = present_index; i < _plot.length; i++) {
        _plot[i] = undefined
      }

      return [{
        label,
        data: _plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
      },
      {
        label,
        data: dashedPlot,
        borderWidth: 3,
        borderDash: [3, 3],
        borderColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
      }]
    } else {
      return [{
        label,
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
      }]
    }
  } else {
    return [{
      label,
      data: plot,
      borderWidth: 2,
      // borderDash: [10, 1],
      borderColor: 'rgba(166,187,210,0.5)',
      pointHoverBackgroundColor: 'rgba(166,187,210,0.8)',
      pointBorderColor: 'transparent',
      pointHoverBorderColor: 'transparent',
      pointHoverRadius: 4,
      backgroundColor: prev_gradient,
    }]
  }
}

const MONTHS = [
  "January", "February", "March",
  "April", "May", "June", "July",
  "August", "September", "October",
  "November", "December"
]

const MONTHS_ABBREV = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

const DAYS_ABBREV = [
  "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
]

const GRAPH_METRICS = [
  'u_visitors',
  'pageviews',
  'bounce',
  'duration',
  'time',
  'conversion_rate',
  'u_conversions',
  't_conversions'
]

const METRIC_MAPPING = {
  'Unique visitors (last 30 min)': 'u_visitors',
  'Pageviews (last 30 min)': 'pageviews',
  'Unique visitors': 'u_visitors',
  'Unique conversions': 'u_conversions',
  'Total conversions': 't_conversions',
  'Conversion rate': 'conversion_rate',
  'Visit duration': 'duration',
  'Time on Page': 'time',
  'Total pageviews': 'pageviews',
  'Bounce rate': 'bounce',
}

const METRIC_LABELS = {
  'u_visitors': 'Visitors',
  'pageviews': 'Pageviews',
  'bounce': 'Bounce Rate',
  'duration': 'Visit Duration',
  'time': 'Time on Page',
  'conversion_rate': 'Conversion Rate',
  'u_conversions': 'Converted Visitors',
  't_conversions': 'Total Conversions'
}

const METRIC_FORMATTER = {
  'u_visitors': numberFormatter,
  'pageviews': numberFormatter,
  'bounce': (number) => (`${Math.max(number, 100)}%`),
  'duration': durationFormatter,
  'time': durationFormatter,
  'conversion_rate': (number) => (`${Math.max(number, 100)}%`),
  'u_conversions': numberFormatter,
  't_conversions': numberFormatter
}

function dateFormatter(interval, longForm) {
  return function (isoDate, index, ticks) {
    let date = new Date(isoDate)

    if (interval === 'month') {
      return MONTHS[date.getUTCMonth()];
    } else if (interval === 'date') {
      var day = DAYS_ABBREV[date.getUTCDay()];
      var date_ = date.getUTCDate();
      var month = MONTHS_ABBREV[date.getUTCMonth()];
      return day + ', ' + date_ + ' ' + month;
    } else if (interval === 'hour') {
      const parts = isoDate.split(/[^0-9]/);
      date = new Date(parts[0], parts[1] - 1, parts[2], parts[3], parts[4], parts[5])
      var hours = date.getHours(); // Not sure why getUTCHours doesn't work here
      var ampm = hours >= 12 ? 'pm' : 'am';
      hours = hours % 12;
      hours = hours ? hours : 12; // the hour '0' should be '12'
      return hours + ampm;
    } else if (interval === 'minute') {
      if (longForm) {
        const minutesAgo = Math.abs(isoDate)
        return minutesAgo === 1 ? '1 minute ago' : minutesAgo + ' minutes ago'
      } else {
        return isoDate + 'm'
      }
    }
  }
}

class LineGraph extends React.Component {
  constructor(props) {
    super(props);
    this.regenerateChart = this.regenerateChart.bind(this);
    this.updateWindowDimensions =  this.updateWindowDimensions.bind(this);
  }

  regenerateChart() {
    const { graphData, comparison, metric } = this.props
    this.ctx = document.getElementById("main-graph-canvas").getContext('2d');
    const dataSet = buildDataSet(graphData.plot, graphData.present_index, this.ctx, METRIC_LABELS[metric])
    const prev_dataSet = buildDataSet(graphData.prev_plot, false, this.ctx, METRIC_LABELS[metric], true)
    const combinedDataSets = comparison.enabled ? [...dataSet, ...prev_dataSet] : dataSet;

    return new Chart(this.ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: combinedDataSets
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
            external: function (context) {
              const tooltipModel = context.tooltip;

              // Canvas Offset from 0,0
              const offset = this._chart.canvas.getBoundingClientRect();
              // Tooltip Element
              let tooltipEl = document.getElementById('chartjs-tooltip');

              // Create element on first render
              if (!tooltipEl) {
                tooltipEl = document.createElement('div');
                tooltipEl.id = 'chartjs-tooltip';
                tooltipEl.style.display = 'none';
                document.body.appendChild(tooltipEl);
              }

              if (tooltipEl && offset && window.innerWidth < 768) {
                tooltipEl.style.top = offset.y + offset.height + window.pageYOffset + 'px'
                tooltipEl.style.left = offset.x + window.pageXOffset + 'px'
                tooltipEl.style.right = 'unset'
                tooltipEl.style.display = 'unset'
              }

              // Stop if no tooltip showing
              if (tooltipModel.opacity === 0) {
                tooltipEl.style.opacity = 0;
                return;
              }

              function getBody(bodyItem) {
                return bodyItem.lines;
              }

              // Set Tooltip Body
              if (tooltipModel.body) {
                var bodyLines = tooltipModel.body.map(getBody);

                // Remove duplicated line on overlap between dashed and normal
                if (bodyLines.length == 3) {
                  bodyLines[1] = false
                }

                const data = tooltipModel.dataPoints[0]
                const label = graphData.labels[data.dataIndex]
                const point = data.raw || 0

                const prev_data = tooltipModel.dataPoints.slice(-1)[0]
                const prev_label = graphData.prev_labels[prev_data.dataIndex]
                const prev_point = prev_data.raw || 0
                const pct_change = point === prev_point ? 0 : prev_point === 0 ? 100 : Math.round(((point - prev_point) / prev_point * 100).toFixed(1))

                function renderLabel(isPrevious) {
                  const formattedLabel = dateFormatter(graphData.interval, true)(label)
                  const prev_formattedLabel = dateFormatter(graphData.interval, true)(prev_label)

                  if (graphData.interval === 'month') {
                    return !isPrevious ? `${formattedLabel} ${(new Date(label)).getUTCFullYear()}` : `${prev_formattedLabel} ${(new Date(prev_label)).getUTCFullYear()}`
                  }

                  if (graphData.interval === 'date') {
                    return !isPrevious ? formattedLabel : prev_formattedLabel
                  }

                  if (graphData.interval === 'hour') {
                    return !isPrevious ? `${dateFormatter("date", true)(label)}, ${formattedLabel}` : `${dateFormatter("date", true)(prev_label)}, ${dateFormatter(graphData.interval, true)(prev_label)}`
                  }

                  return !isPrevious ? formattedLabel : prev_formattedLabel
                }

                function renderComparison(change) {
                  const formattedComparison = numberFormatter(Math.abs(change))

                  if (change > 0) {
                    return `<span class='text-green-500 font-bold'>${formattedComparison}%</span>`
                  }
                  if (change < 0) {
                    return `<span class='text-red-400 font-bold'>${formattedComparison}%</span>`
                  }
                  if (change === 0) {
                    return `<span class='font-bold'>0%</span>`
                  }
                }

                let innerHtml = `
                <div class='text-gray-100 flex flex-col'>
                  <div class='flex justify-between items-center'>
                      <span class='font-bold mr-4 text-lg'>${METRIC_LABELS[metric]}</span>
                      ${graphData.interval === 'minute' || !comparison.enabled ? '' : renderComparison(pct_change)}
                  </div>
                  <div class='flex flex-col'>
                    <div class='flex flex-row justify-between items-center'>
                      <span class='flex items-center mr-4'>
                        <div class='w-3 h-3 mr-1 rounded-full' style='background-color: rgba(101,116,205)'></div>
                        <span>${renderLabel()}</span>
                      </span>
                      <span>${METRIC_FORMATTER[metric](point)}</span>
                    </div>
                    ${graphData.interval === 'minute' || !comparison.enabled ? '' : `
                      <div class='flex flex-row justify-between items-center mt-1'>
                        <span class='flex items-center mr-4'>
                          <div class='w-3 h-3 mr-1 rounded-full' style='background-color: rgba(166,187,210,0.5)'></div>
                          <span>${renderLabel(true)}</span>
                        </span>
                        <span>${METRIC_FORMATTER[metric](prev_point)}</span>
                      </div>
                    `}
                  </div>
                  <span class='font-bold text-'>${graphData.interval === 'month' ? 'Click to view month' : graphData.interval === 'date' ? 'Click to view day' : ''}</span>
                </div>
                `;

                tooltipEl.innerHTML = innerHtml;
              }
              tooltipEl.style.opacity = 1;
            }
          },
        },
        responsive: true,
        onResize: this.updateWindowDimensions,
        elements: { line: { tension: 0.1 }, point: { radius: 0 } },
        onClick: this.onClick.bind(this),
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: numberFormatter,
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
              callback: function (val, index, ticks) { return dateFormatter(graphData.interval)(this.getLabelForValue(val)) },
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            }
          }
        }
      }
    });
  }

  repositionTooltip(e) {
    const tooltipEl = document.getElementById('chartjs-tooltip');
    if (tooltipEl && window.innerWidth >= 768) {
      if (e.clientX > 0.66 * window.innerWidth) {
        tooltipEl.style.right = (window.innerWidth - e.clientX) + window.pageXOffset + 'px'
        tooltipEl.style.left = 'unset'
      } else {
        tooltipEl.style.right = 'unset'
        tooltipEl.style.left = e.clientX + window.pageXOffset + 'px'
      }
      tooltipEl.style.top = e.clientY + window.pageYOffset + 'px'
      tooltipEl.style.display = 'unset';
    }
  }

  componentDidMount() {
    this.chart = this.regenerateChart();
    window.addEventListener('mousemove', this.repositionTooltip);
  }

  componentDidUpdate(prevProps) {
    const { graphData, comparison, metric, darkTheme } = this.props;

    if (
      graphData !== prevProps.graphData ||
      comparison.enabled !== prevProps.comparison.enabled ||
      metric !== prevProps.metric ||
      darkTheme !== prevProps.darkTheme
    ) {
      this.chart.destroy();
      this.chart = this.regenerateChart();
      this.chart.update();
    }

    if (!metric) {
      this.chart.destroy();
    }
  }

  componentWillUnmount() {
    // Ensure that the tooltip doesn't hang around when we are loading more data
    const tooltip = document.getElementById('chartjs-tooltip');
    if (tooltip) {
      tooltip.style.opacity = 0;
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

  renderComparison(name, comparison) {
    const formattedComparison = numberFormatter(Math.abs(comparison))

    if (comparison > 0) {
      const color = name === 'Bounce rate' ? 'text-red-400' : 'text-green-500'
      return <span className="text-xs dark:text-gray-100"><span className={color + ' font-bold'}>&uarr;</span> {formattedComparison}%</span>
    } else if (comparison < 0) {
      const color = name === 'Bounce rate' ? 'text-green-500' : 'text-red-400'
      return <span className="text-xs dark:text-gray-100"><span className={color + ' font-bold'}>&darr;</span> {formattedComparison}%</span>
    } else if (comparison === 0) {
      return <span className="text-xs text-gray-700 dark:text-gray-300">&#12336; N/A</span>
    }
  }

  topStatNumberShort(stat) {
    if (['visit duration', 'time on page'].includes(stat.name.toLowerCase())) {
      return durationFormatter(stat.value)
    } else if (['bounce rate', 'conversion rate'].includes(stat.name.toLowerCase())) {
      return stat.value + '%'
    } else {
      return numberFormatter(stat.value)
    }
  }

  topStatTooltip(stat) {
    if (typeof(stat.value) == 'number') {
      let name = stat.name.toLowerCase()
      name = stat.value === 1 ? name.slice(0, -1) : name
      return stat.value.toLocaleString() + ' ' + name
    }
  }

  renderTopStats() {
    const { graphData, updateMetric, metric } = this.props
    const stats = this.props.graphData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-gray-300' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border

      return (
        <div className={`px-6 w-1/2 my-4 lg:w-auto ${border}`} key={stat.name}>
          {stat.name === 'Current visitors' ?
            (
              <div className='text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex'>
                {stat.name}
              </div>
            ) : (
              <div
                className='text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap cursor-pointer flex'
                title={metric == METRIC_MAPPING[stat.name] ?
                  `Hide ${METRIC_LABELS[METRIC_MAPPING[stat.name]].toLowerCase()} from graph` :
                  `Show ${METRIC_LABELS[METRIC_MAPPING[stat.name]].toLowerCase()} on graph`
                }
                onClick={() => { updateMetric(stat.name) }}
                tabIndex={0}
              >
                {metric == METRIC_MAPPING[stat.name] &&
                  <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"></path></svg>
                }
                {stat.name}
              </div>
            )}
          <div className="flex items-center justify-between my-1 whitespace-nowrap">
            <b className="mr-4 text-xl md:text-2xl dark:text-gray-100" tooltip={this.topStatTooltip(stat)}>{this.topStatNumberShort(stat)}</b>
            {this.renderComparison(stat.name, stat.change)}
          </div>
        </div>
      )
    })

    if (graphData.interval === 'minute') {
      stats.push(<div key="dot" className="block pulsating-circle" style={{ left: '125px', top: '52px' }}></div>)
    }

    return stats
  }

  downloadLink() {
    if (this.props.query.period !== 'realtime') {
      const endpoint = `/${encodeURIComponent(this.props.site.domain)}/visitors.csv${api.serializeQuery(this.props.query)}`

      return (
        <a href={endpoint} download>
          <svg className="absolute w-4 h-5 text-gray-700 feather dark:text-gray-300 -top-8 right-8" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
        </a>
      )
    }
  }

  samplingNotice() {
    const samplePercent = this.props.graphData.sample_percent

    if (samplePercent < 100) {
      return (
        <div tooltip={`Stats based on a ${samplePercent}% sample of all visitors`} className="absolute cursor-pointer -top-20 right-8">
          <svg className="w-4 h-4 text-gray-300 dark:text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
      )
    }
  }

  render() {
    const extraClass = this.props.graphData.interval === 'hour' ? '' : 'cursor-pointer'

    return (
      <div className="graph-inner">
        <div className="flex flex-wrap">
          {this.renderTopStats()}
        </div>
        <div className="relative px-2">
          {this.props.metric && this.downloadLink()}
          {this.samplingNotice()}
          <canvas id="main-graph-canvas" className={'mt-4 ' + extraClass} width="1054" height="342"></canvas>
        </div>
      </div>
    )
  }
}

LineGraph = withRouter(withComparisonConsumer(LineGraph))

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      metric: storage.getItem('graph__metric') || 'u_visitors'
    }
    this.onVisible = this.onVisible.bind(this)
    this.updateMetric = this.updateMetric.bind(this)
  }

  onVisible() {
    this.fetchGraphData()
    if (this.props.timer) this.props.timer.onTick(this.fetchGraphData.bind(this))
  }

  componentDidUpdate(prevProps, prevState) {
    const { graphData, metric } = this.state;

    if (
      this.props.query !== prevProps.query ||
      metric !== prevState.metric
    ) {
      this.setState({ loading: true, graphData: null })
      this.fetchGraphData()
    }

    const savedMetric = storage.getItem('graph__metric')
    const topStatLabels = graphData && graphData.top_stats.map(({ name }) => METRIC_MAPPING[name]).filter(name => name)
    const prevTopStatLabels = prevState.graphData && prevState.graphData.top_stats.map(({ name }) => METRIC_MAPPING[name]).filter(name => name)
    if (topStatLabels && `${topStatLabels}` !== `${prevTopStatLabels}`) {
      if (!topStatLabels.includes(savedMetric) && savedMetric !== "") {
        this.setState({ metric: topStatLabels[0] })
      } else {
        this.setState({ metric: savedMetric })
      }
    }
  }

  updateMetric(newMetricLabel) {
    const newMetric = METRIC_MAPPING[newMetricLabel]
    if (newMetric === this.state.metric) {
      storage.setItem('graph__metric', "")
      this.setState({ metric: "" })
    } else {
      storage.setItem('graph__metric', newMetric)
      this.setState({ metric: newMetric })
    }
  }

  fetchGraphData() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/main-graph/${this.state.metric || 'none'}`, this.props.query)
      .then((res) => {
        this.setState({ loading: false, graphData: res })
        return res
      })
  }

  renderInner() {
    const { query, site } = this.props;
    const { graphData, metric } = this.state;

    if (graphData) {
      return (
        <ThemeContext.Consumer>
          {theme => (
            <LineGraph graphData={graphData} site={site} query={query} darkTheme={theme} metric={metric} updateMetric={this.updateMetric} />
          )}
        </ThemeContext.Consumer>
      )
    }
  }

  render() {
    return (
      <LazyLoader onVisible={this.onVisible}>
        <div className={`relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825 ${this.state.metric ? 'main-graph' : 'top-stats-only'}`}>
          {this.state.loading && <div className="graph-inner"><div className={`${this.state.metric ? 'pt-24 sm:pt-32 md:pt-48' : 'pt-16 sm:pt-14 md:pt-18 lg:pt-5'} mx-auto loading`}><div></div></div></div>}
          {this.renderInner()}
        </div>
      </LazyLoader>
    )
  }
}
