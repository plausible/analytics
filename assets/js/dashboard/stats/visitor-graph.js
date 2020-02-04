import React from 'react';
import { withRouter } from 'react-router-dom'
import Chart from 'chart.js'
import { eventName } from '../query'
import numberFormatter from '../number-formatter'
import { isToday, shiftMonths, formatMonth } from '../date'
import * as api from '../api'

function mainSet(plot, present_index, ctx) {
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
        label: 'Visitors',
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        backgroundColor: gradient,
      },
      {
        label: 'Visitors',
        data: dashedPlot,
        borderWidth: 3,
        borderDash: [5, 10],
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        backgroundColor: gradient,
    }]
  } else {
    return [{
      label: 'Visitors',
      data: plot,
      borderWidth: 3,
      borderColor: 'rgba(101,116,205)',
      pointBackgroundColor: 'rgba(101,116,205)',
      backgroundColor: gradient,
    }]
  }
}

function compareSet(plot, present_index, ctx) {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(255, 68, 87, .2)');
  gradient.addColorStop(1, 'rgba(255, 68, 87, 0)');

  if (present_index) {
    var dashedPart = plot.slice(present_index - 1);
    var dashedPlot = (new Array(plot.length - dashedPart.length)).concat(dashedPart)
    for(var i = present_index; i < plot.length; i++) {
      plot[i] = undefined
    }

    return [{
        label: 'Conversions',
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(255, 68, 87, 1)',
        pointBackgroundColor: 'rgba(255, 68, 87, 1)',
        backgroundColor: gradient,
      },
      {
        label: 'Conversions',
        data: dashedPlot,
        borderWidth: 3,
        borderDash: [5, 10],
        borderColor: 'rgba(255, 68, 87, 1)',
        pointBackgroundColor: 'rgba(255, 68, 87, 1)',
        backgroundColor: gradient,
    }]
  } else {
    return [{
      label: 'Conversions',
      data: plot,
      borderWidth: 3,
      borderColor: 'rgba(255, 68, 87, 1)',
      pointBackgroundColor: 'rgba(255, 68, 87, 1)',
      backgroundColor: gradient,
    }]
  }
}

function dataSets(graphData, ctx) {
  const dataSets = mainSet(graphData.plot, graphData.present_index, ctx)

  if (graphData.compare_plot) {
    return dataSets.concat(compareSet(graphData.compare_plot, graphData.present_index, ctx))
  } else {
    return dataSets
  }
}

const MONTHS = [
  "January", "February", "March",
  "April", "May", "June", "July",
  "August", "September", "October",
  "November", "December"
]

function dateFormatter(graphData) {
  return function(isoDate) {
    const date = new Date(isoDate)

    if (graphData.interval === 'month') {
      return MONTHS[date.getUTCMonth()];
    } else if (graphData.interval === 'date') {
      return date.getUTCDate() + ' ' + MONTHS[date.getUTCMonth()];
    } else if (graphData.interval === 'hour') {
      var hours = date.getHours(); // Not sure why getUTCHours doesn't work here
      var ampm = hours >= 12 ? 'pm' : 'am';
      hours = hours % 12;
      hours = hours ? hours : 12; // the hour '0' should be '12'
      return hours + ampm;
    }
  }
}

function formatStat(stat) {
  if (typeof(stat.count) === 'number') {
    return numberFormatter(stat.count)
  } else if (typeof(stat.duration) === 'number') {
    return new Date(stat.duration * 1000).toISOString().substr(14, 5)
  } else if (typeof(stat.percentage) === 'number') {
    return stat.percentage + '%'
  }
}

class LineGraph extends React.Component {
  componentDidMount() {
    const {graphData} = this.props
    const ctx = document.getElementById("main-graph-canvas").getContext('2d');

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: dataSets(graphData, ctx)
      },
      options: {
        animation: false,
        legend: {display: false},
        responsive: true,
        elements: {line: {tension: 0}, point: {radius: 0}},
        onClick: this.onClick.bind(this),
        tooltips: {
          mode: 'index',
          intersect: false,
          xPadding: 10,
          yPadding: 10,
          titleFontSize: 18,
          footerFontSize: 14,
          bodyFontSize: 14,
          backgroundColor: 'rgba(25, 30, 56)',
          titleMarginBottom: 8,
          bodySpacing: 6,
          footerMarginTop: 8,
          xPadding: 16,
          yPadding: 12,
          multiKeyBackground: 'none',
          callbacks: {
            title: function(dataPoints) {
              const data = dataPoints[0]
              return dateFormatter(graphData)(data.xLabel)
            },
            beforeBody: function() {
              this.drawnLabels = {}
            },
            label: function(item) {
              const dataset = this._data.datasets[item.datasetIndex]
              if (!this.drawnLabels[dataset.label]) {
                this.drawnLabels[dataset.label] = true
                return ` ${item.yLabel} ${dataset.label}`
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
        scales: {
          yAxes: [{
            ticks: {
              callback: numberFormatter,
              beginAtZero: true,
              autoSkip: true,
              maxTicksLimit: 8,
            },
            gridLines: {
              zeroLineColor: 'transparent',
              drawBorder: false,
            }
          }],
          xAxes: [{
            gridLines: {
              display: false,
            },
            ticks: {
              autoSkip: true,
              maxTicksLimit: 8,
              callback: dateFormatter(graphData),
            }
          }]
        }
      }
    });
  }

  onClick(e) {
    const query = new URLSearchParams(window.location.search)
    const element = this.chart.getElementsAtEventForMode(e, 'index', {intersect: false})[0]
    const date = element._chart.config.data.labels[element._index]
    if (this.props.graphData.interval === 'month') {
      query.set('period', 'month')
      query.set('date', date)
      this.props.history.push({search: query.toString()})
    } else if (this.props.graphData.interval === 'date') {
      query.set('period', 'day')
      query.set('date', date)
      this.props.history.push({search: query.toString()})
    }
  }

  comparisonTimeframe() {
    const {query, site} = this.props

    if (query.period === 'day') {
      if (isToday(site, query.date)) {
        return 'yesterday'
      } else {
        return 'previous day'
      }
    } else if (query.period === 'month') {
      return formatMonth(shiftMonths(query.date, -1))
    } else if (query.period === '7d') {
      return 'last week'
    } else if (query.period === '30d') {
      return 'last month'
    } else if (query.period === '60d') {
      return 'prev 60 days'
    } else if (query.period === '6mo') {
      return 'prev 6 months'
    } else if (query.period === '12mo') {
      return 'last year'
    }
  }

  renderComparison(name, comparison) {
    const formattedComparison = numberFormatter(Math.abs(comparison))

    if (comparison > 0) {
      const color = name === 'Bounce rate' ? 'text-red-light' : 'text-green-dark'
      return <span className="py-1 text-xs text-grey-darker"><span className={color}>&uarr;</span> {formattedComparison}% from {this.comparisonTimeframe()}</span>
    } else if (comparison < 0) {
      const color = name === 'Bounce rate' ? 'text-green-dark' : 'text-red-light'
      return <span className="py-1 text-xs text-grey-darker"><span className={color}>&darr;</span> {formattedComparison}% from {this.comparisonTimeframe()}</span>
    } else if (comparison === 0) {
      return <span className="py-1 text-xs text-grey-darker">&#12336; same as {this.comparisonTimeframe()}</span>
    }
  }

  renderTopStats() {
    const {graphData} = this.props
    return this.props.graphData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-grey-light' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border

      return (
        <div className={`pl-8 w-1/2 my-4 lg:w-52 ${border}`} key={stat.name}>
          <div className="text-grey-dark text-xs font-bold tracking-wide uppercase">{stat.name}</div>
          <div className="my-1 flex items-end justify-between">
            <b className="text-2xl">{formatStat(stat)}</b>
          </div>
          {this.renderComparison(stat.name, stat.change)}
        </div>
      )
    })
  }

  downloadLink() {
    const endpoint = `/${encodeURIComponent(this.props.site.domain)}/visitors.csv${api.serializeQuery(this.props.query)}`

    return (
      <a href={endpoint} download>
        <svg className="w-4 h-5 absolute text-grey-darker" style={{right: '2rem', top: '-2rem'}}>
          <use xlinkHref="#feather-download" />
        </svg>
      </a>
    )
  }

  render() {
    const extraClass = this.props.graphData.interval === 'hour' ? '' : 'cursor-pointer'

    return (
      <React.Fragment>
        <div className="flex flex-wrap">
          { this.renderTopStats() }
        </div>
        <div className="px-2 relative">
          { this.downloadLink() }
          <canvas id="main-graph-canvas" className={'mt-4 ' + extraClass} width="1054" height="342"></canvas>
        </div>
      </React.Fragment>
    )
  }
}

LineGraph = withRouter(LineGraph)

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchGraphData()
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
    if (this.state.loading) {
      return (
        <div className="loading pt-24 sm:pt-32 md:pt-48 mx-auto"><div></div></div>
      )
    } else if (this.state.graphData) {
      return <LineGraph graphData={this.state.graphData} site={this.props.site} query={this.props.query} />
    }
  }

  render() {
    return (
      <div className="w-full bg-white shadow-md rounded mt-6 main-graph">
        { this.renderInner() }
      </div>
    )
  }
}
