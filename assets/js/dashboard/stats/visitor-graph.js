import React from 'react';
import numberFormatter from '../number-formatter'
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

function onClick(graphData) {
  return function(e) {
    const element = this.getElementsAtEventForMode(e, 'index', {intersect: false})[0]
    const date = element._chart.config.data.labels[element._index]
    if (graphData.interval === 'month') {
      document.location = '?period=month&date=' + date
    } else if (graphData.interval === 'date') {
      document.location = '?period=day&date=' + date
    }
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

    new Chart(ctx, {
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
        onClick: onClick(graphData),
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
              var data = dataPoints[0]
              if (graphData.interval === 'month') {
                return data.yLabel.toLocaleString() + ' visitors in ' + data.xLabel
              } else if (graphData.interval === 'date') {
                return data.yLabel.toLocaleString() + ' visitors on ' + data.xLabel
              } else if (graphData.interval === 'hour') {
                return data.yLabel.toLocaleString() + ' visitors at ' + data.xLabel
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

  renderComparison(comparison) {
    const formattedComparison = numberFormatter(Math.abs(comparison))

    if (comparison >= 0) {
      return <span className="bg-green-lightest text-green-dark px-2 py-1 text-xs font-bold rounded">&uarr; {formattedComparison}%</span>
    } else if (comparison < 0) {
      return <span className="bg-red-lightest text-red-dark px-2 py-1 text-xs font-bold rounded">&darr; {formattedComparison}%</span>
    }
  }

  render() {
    const {graphData, comparisons} = this.props

    return (
      <React.Fragment>
        <div className="border-b border-grey-light flex p-4">
          <div className="border-r border-grey-light pl-2 pr-10">
            <div className="text-grey-dark text-sm font-bold tracking-wide">UNIQUE VISITORS</div>
            <div className="mt-2 flex items-center justify-between">
              <b className="text-2xl" title={graphData.unique_visitors.toLocaleString()}>{numberFormatter(graphData.unique_visitors)}</b>
              {this.renderComparison(comparisons.change_visitors)}
            </div>
          </div>
          <div className="px-10">
            <div className="text-grey-dark text-sm font-bold tracking-wide">TOTAL PAGEVIEWS</div>
            <div className="mt-2 flex items-center justify-between">
              <b className="text-2xl" title={graphData.pageviews.toLocaleString()}>{numberFormatter(graphData.pageviews)}</b>
              {this.renderComparison(comparisons.change_pageviews)}
            </div>
          </div>
        </div>
        <div className="p-4">
          <canvas id="main-graph-canvas" className="mt-4 ${extraClass}" width="1054" height="329"></canvas>
        </div>
      </React.Fragment>
    )
  }
}

export default class VisitorGraph extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      comparisons: {}
    }
  }

  componentDidMount() {
    api.get(`/api/stats/${this.props.site.domain}/main-graph`, this.props.query)
      .then((res) => {
        this.setState({loading: false, graphData: res})
        return res
      })
      .then(graphData => api.get(`/api/${this.props.site.domain}/compare`, Object.assign({}, this.props.query, {pageviews: graphData.pageviews, unique_visitors: graphData.unique_visitors})))
      .then(res => this.setState({comparisons: res}))
  }

  renderInner() {
    if (this.state.loading) {
      return (
        <div className="loading pt-24 sm:pt-32 md:pt-48 mx-auto"><div></div></div>
      )
    } else if (this.state.graphData) {
      return <LineGraph graphData={this.state.graphData} comparisons={this.state.comparisons} />
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
