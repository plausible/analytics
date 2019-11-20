import React from 'react';
import { withRouter } from 'react-router-dom'
import Chart from 'chart.js'
import { eventName } from '../query'
import numberFormatter from '../number-formatter'
import { isToday, shiftMonths, formatMonth } from '../date'
import * as api from '../api'

function dataSets(graphData, ctx) {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');

  if (graphData.present_index) {
    var dashedPart = graphData.plot.slice(graphData.present_index - 1);
    var dashedPlot = (new Array(graphData.plot.length - dashedPart.length)).concat(dashedPart)
    for(var i = graphData.present_index; i < graphData.plot.length; i++) {
      graphData.plot[i] = undefined
    }

    return [{
        label: 'Visitors',
        data: graphData.plot,
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
      data: graphData.plot,
      borderWidth: 3,
      borderColor: 'rgba(101,116,205)',
      pointBackgroundColor: 'rgba(101,116,205)',
      backgroundColor: gradient,
    }]
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
        elements: {line: {tension: 0.1}, point: {radius: 0}},
        onClick: this.onClick.bind(this),
        tooltips: {
          mode: 'index',
          intersect: false,
          xPadding: 10,
          yPadding: 10,
          titleFontSize: 16,
          footerFontSize: 14,
          footerFontColor: '#e6e8ff',
          backgroundColor: 'rgba(25, 30, 56)',
          callbacks: {
            title: function(dataPoints) {
              const data = dataPoints[0]
              const formatDate = dateFormatter(graphData)
              if (graphData.interval === 'month') {
                return data.yLabel.toLocaleString() + ' visitors in ' + formatDate(data.xLabel)
              } else if (graphData.interval === 'date') {
                return data.yLabel.toLocaleString() + ' visitors on ' + formatDate(data.xLabel)
              } else if (graphData.interval === 'hour') {
                return data.yLabel.toLocaleString() + ' visitors at ' + formatDate(data.xLabel)
              }
            },
            label: function() {},
            afterBody: function(dataPoints) {
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
    const element = this.chart.getElementsAtEventForMode(e, 'index', {intersect: false})[0]
    const date = element._chart.config.data.labels[element._index]
    if (this.props.graphData.interval === 'month') {
      this.props.history.push('?period=month&date=' + date)
    } else if (this.props.graphData.interval === 'date') {
      this.props.history.push('?period=day&date=' + date)
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
    } else if (query.period === '3mo') {
      return 'previous 3 months'
    } else if (query.period === '6mo') {
      return 'previous 6 months'
    }
  }

  renderComparison(comparison) {
    const formattedComparison = numberFormatter(Math.abs(comparison))

    if (comparison > 0) {
      return <span className="py-1 text-xs text-grey-darker"><span className="text-green-dark">&uarr;</span> {formattedComparison}% from {this.comparisonTimeframe()}</span>
    } else if (comparison < 0) {
      return <span className="py-1 text-xs text-grey-darker"><span className="text-red-light">&darr;</span> {formattedComparison}% from {this.comparisonTimeframe()}</span>
    } else if (comparison === 0) {
      return <span className="py-1 text-xs text-grey-darker">&#12336; same as {this.comparisonTimeframe()}</span>
    }
  }

  render() {
    const {graphData} = this.props
    const extraClass = graphData.interval === 'hour' ? '' : 'cursor-pointer'

    return (
      <React.Fragment>
        <div className="border-b border-grey-light flex p-4">
          <div className="border-r border-grey-light pl-2 w-52">
            <div className="text-grey-dark text-xs font-bold tracking-wide">UNIQUE VISITORS</div>
            <div className="my-1 flex items-end justify-between">
              <b className="text-2xl" title={graphData.unique_visitors.toLocaleString()}>{numberFormatter(graphData.unique_visitors)}</b>
            </div>
            {this.renderComparison(graphData.change_visitors)}
          </div>
          <div className="pl-8 w-60">
            <div className="text-grey-dark text-xs font-bold tracking-wide uppercase">TOTAL {eventName(this.props.query)}</div>
            <div className="my-1 flex items-end justify-between">
              <b className="text-2xl" title={graphData.pageviews.toLocaleString()}>{numberFormatter(graphData.pageviews)}</b>
            </div>
            {this.renderComparison(graphData.change_pageviews)}
          </div>
        </div>
        <div className="p-4">
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
    api.get(`/api/stats/${this.props.site.domain}/main-graph`, this.props.query)
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
