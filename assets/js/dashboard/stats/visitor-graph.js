import React from 'react';
import { withRouter } from 'react-router-dom'
import Chart from 'chart.js/auto';
import { eventName, navigateToQuery } from '../query'
import numberFormatter, {durationFormatter} from '../number-formatter'
import * as api from '../api'
import {ThemeContext} from '../theme-context'
import LazyLoader from '../lazy-loader'

function buildDataSet(plot, present_index, ctx, label) {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');

  if (present_index) {
    var dashedPart = plot.slice(present_index - 1);
    var dashedPlot = (new Array(plot.length - dashedPart.length)).concat(dashedPart)
    for(var i = present_index; i < plot.length; i++) {
      plot[i] = undefined
    }

    return [{
        label: label,
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        backgroundColor: gradient,
        fill: true
      },
      {
        label: label,
        data: dashedPlot,
        borderWidth: 3,
        borderDash: [5, 10],
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        backgroundColor: gradient,
        fill: true
    }]
  } else {
    return [{
      label: label,
      data: plot,
      borderWidth: 3,
      borderColor: 'rgba(101,116,205)',
      pointBackgroundColor: 'rgba(101,116,205)',
      backgroundColor: gradient,
      fill: true
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

function dateFormatter(interval, longForm) {
  return function(isoDate, index, ticks) {
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
      date = new Date(parts[0],parts[1]-1,parts[2],parts[3],parts[4],parts[5])
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
    const {graphData} = this.props
    this.ctx = document.getElementById("main-graph-canvas").getContext('2d');
    const label = this.props.query.filters.goal ? 'Converted visitors' : graphData.interval === 'minute' ? 'Pageviews' : 'Visitors'
    const dataSet = buildDataSet(graphData.plot, graphData.present_index, this.ctx, label)

    return new Chart(this.ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: dataSet
      },
      options: {
        animation: false,
        plugins: {
          legend: {display: false},
          tooltip: {
            mode: 'index',
            intersect: false,
            titleFont: {size: 18},
            footerFont: {size: 14},
            bodyFont: {size: 14},
            backgroundColor: 'rgba(25, 30, 56)',
            titleMarginBottom: 8,
            bodySpacing: 6,
            footerMarginTop: 8,
            padding: {x: 10, y: 10},
            multiKeyBackground: 'none',
            callbacks: {
              title: function(dataPoints) {
                const data = dataPoints[0]
                return dateFormatter(graphData.interval, true)(data.label)
              },
              beforeBody: function() {
                this.drawnLabels = {}
              },
              label: function(item) {
                const dataset = item.dataset
                if (!this.drawnLabels[dataset.label]) {
                  this.drawnLabels[dataset.label] = true
                  const pluralizedLabel = item.formattedValue === "1" ? dataset.label.slice(0, -1) : dataset.label
                  return ` ${item.formattedValue} ${pluralizedLabel}`
                }
              },
              footer: function(dataPoints) {
                if (graphData.interval === 'month') {
                  return 'Click to view month'
                } else if (graphData.interval === 'date') {
                  return 'Click to view day'
                }
              }
            }
          },
        },
        responsive: true,
        onResize: this.updateWindowDimensions,
        elements: {line: {tension: 0}, point: {radius: 0}},
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
            grid: {display: false},
            ticks: {
              maxTicksLimit: 8,
              callback: function(val, index, ticks) { return dateFormatter(graphData.interval)(this.getLabelForValue(val)) },
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            }
          }
        }
      }
    });
  }

  componentDidMount() {
    this.chart = this.regenerateChart();
  }

  componentDidUpdate(prevProps) {
    if (this.props.graphData !== prevProps.graphData) {
      const label = this.props.query.filters.goal ? 'Converted visitors' : this.props.graphData.interval === 'minute' ? 'Pageviews' : 'Visitors'
      const newDataset = buildDataSet(this.props.graphData.plot, this.props.graphData.present_index, this.ctx, label)

      for (let i = 0; i < newDataset[0].data.length; i++) {
        this.chart.data.datasets[0].data[i] = newDataset[0].data[i]
      }

      this.chart.update()
    }

    if (prevProps.darkTheme !== this.props.darkTheme) {
      this.chart.destroy();
      this.chart = this.regenerateChart();
      this.chart.update();
    }
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
    const element = this.chart.getElementsAtEventForMode(e, 'index', {intersect: false})[0]
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
    if (typeof(stat.duration) == 'number') {
      return durationFormatter(stat.duration)
    } else if (typeof(stat.count) == 'number') {
      return numberFormatter(stat.count)
    } else {
      return stat.percentage + '%'
    }
  }

  topStatTooltip(stat) {
    if (typeof(stat.count) == 'number') {
      let name = stat.name.toLowerCase()
      name = stat.count === 1 ? name.slice(0, -1) : name
      return stat.count.toLocaleString() + ' ' + name
    }
  }

  renderTopStats() {
    const {graphData} = this.props
    const stats = this.props.graphData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-gray-300' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border

      return (
        <div className={`px-8 w-1/2 my-4 lg:w-auto ${border}`} key={stat.name}>
          <div className="text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap">{stat.name}</div>
          <div className="flex items-center justify-between my-1 whitespace-nowrap">
            <b className="mr-4 text-xl md:text-2xl dark:text-gray-100" tooltip={this.topStatTooltip(stat)}>{ this.topStatNumberShort(stat) }</b>
            {this.renderComparison(stat.name, stat.change)}
          </div>
        </div>
      )
    })

    if (graphData.interval === 'minute') {
      stats.push(<div key="dot" className="block pulsating-circle" style={{left: '125px', top: '52px'}}></div>)
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
          <svg className="w-4 h-4 text-gray-300 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
          { this.renderTopStats() }
        </div>
        <div className="relative px-2">
          { this.downloadLink() }
          { this.samplingNotice() }
          <canvas id="main-graph-canvas" className={'mt-4 ' + extraClass} width="1054" height="342"></canvas>
        </div>
      </div>
    )
  }
}

LineGraph = withRouter(LineGraph)

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  onVisible() {
    this.fetchGraphData()
    if (this.props.timer) this.props.timer.onTick(this.fetchGraphData.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, graphData: null})
      this.fetchGraphData()
    }
  }

  fetchGraphData() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/main-graph`, this.props.query)
      .then((res) => {
        this.setState({loading: false, graphData: res})
        return res
      })
  }

  renderInner() {
    if (this.state.graphData) {
      return (
        <ThemeContext.Consumer>
          {theme => (
            <LineGraph graphData={this.state.graphData} site={this.props.site} query={this.props.query} darkTheme={theme}/>
          )}
        </ThemeContext.Consumer>
      )
    }
  }

  render() {
    return (
      <LazyLoader onVisible={this.onVisible}>
        <div className="relative w-full bg-white rounded shadow-xl dark:bg-gray-825 main-graph">
          { this.state.loading && <div className="graph-inner"><div className="pt-24 mx-auto loading sm:pt-32 md:pt-48"><div></div></div></div> }
          { this.renderInner() }
        </div>
      </LazyLoader>
    )
  }
}
