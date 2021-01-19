import React from 'react';
import { withRouter } from 'react-router-dom'
import Chart from 'chart.js'
import { eventName, navigateToQuery } from '../query'
import numberFormatter, {durationFormatter} from '../number-formatter'
import * as api from '../api'
import {ThemeContext} from '../theme-context'

function buildDataSet(plot, present_index, ctx, label, isPrevious) {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  var prev_gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');
  prev_gradient.addColorStop(0, 'rgba(101,116,205, 0.1)');
  prev_gradient.addColorStop(1, 'rgba(101,116,205, 0)');
  if (!isPrevious) {
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
        },
        {
          label: label,
          data: dashedPlot,
          borderWidth: 3,
          borderDash: [5, 10],
          borderColor: 'rgba(101,116,205)',
          pointBackgroundColor: 'rgba(101,116,205)',
          backgroundColor: gradient,
      }]
    } else {
      return [{
        label: label,
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        backgroundColor: gradient,
      }]
    }
  } else {
    return [{
      label: label,
      data: plot,
      borderWidth: 3,
      borderColor: 'rgba(101,116,205,0.3)',
      pointBackgroundColor: 'transparent',
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

function dateFormatter(interval, longForm) {
  return function(isoDate) {
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
  }

  regenerateChart() {
    const {graphData} = this.props
    this.ctx = document.getElementById("main-graph-canvas").getContext('2d');
    const label = this.props.query.filters.goal ? 'Converted visitors' : graphData.interval === 'minute' ? 'Pageviews' : 'Visitors'
    const dataSet = buildDataSet(graphData.plot, graphData.present_index, this.ctx, label)
    const prev_dataSet = buildDataSet(graphData.prev_plot, false, this.ctx, label, true)

    console.log(dataSet)
    console.log(prev_dataSet)

    return new Chart(this.ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: [...dataSet, ...prev_dataSet]
      },
      options: {
        easing: 'easeInExpo',
        legend: {display: false},
        responsive: true,
        elements: {line: {tension: 0}, point: {radius: 0}},
        onClick: this.onClick.bind(this),
        tooltips: {
          mode: 'index',
          position: 'custom',
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
              const data = graphData.labels[dataPoints[0].index]
              const prev_data = graphData.prev_labels[dataPoints[1].index]
              if (graphData.interval === 'month' || graphData.interval === 'date') {
                return dateFormatter(graphData.interval, true)(data) + ' vs ' + dateFormatter(graphData.interval, true)(prev_data)
              }

              return dateFormatter(graphData.interval, true)(data) + ' vs Previous ' + dateFormatter(graphData.interval, true)(prev_data)
            },
            beforeBody: function() {
              this.drawnLabels = {}
            },
            label: function(item) {
              const datasets = this._data.datasets
              const dataset = this._data.datasets[item.datasetIndex]
              const point = datasets[0].data[item.index] || (datasets.slice(-2)[0] && datasets.slice(-2)[0].data[item.index]) || 0
              const prev_point = datasets.slice(-1)[0].data[item.index]
              const pct_change = point === 0 && prev_point !== 0 ? 100 : point === prev_point ? 0 : Math.round((prev_point - point)/point * 100)
              if (!this.drawnLabels[dataset.label]) {
                this.drawnLabels[dataset.label] = true
                const pluralizedLabel = item.yLabel === 1 ? dataset.label.slice(0, -1) : dataset.label
                return ` ${item.yLabel} ${pluralizedLabel} ${prev_point > point ? '↓' : prev_point == point ? '〰' : '↑'} ${numberFormatter(Math.abs(pct_change))}%`
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
              fontColor: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
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
              callback: dateFormatter(graphData.interval),
              fontColor: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            }
          }]
        }
      }
    });
  }

  componentDidMount() {
    this.chart = this.regenerateChart();

    Chart.Tooltip.positioners.custom = function(elements, eventPosition) {
      /** @type {Chart.Tooltip} */
      var tooltip = this;

      return {
          x: elements[0]._model.x,
          y: elements[0]._model.y
      };
  };
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
      this.chart = this.regenerateChart();
      this.chart.update();
    }
  }

  onClick(e) {
    const element = this.chart.getElementsAtEventForMode(e, 'index', {intersect: false})[0]
    const date = element._chart.config.data.labels[element._index]
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

  renderTopStatNumber(stat) {
    if (stat.name === 'Visit duration') {
      return durationFormatter(stat.count)
    } else if (typeof(stat.count) == 'number') {
      return numberFormatter(stat.count)
    } else {
      return stat.percentage + '%'
    }
  }

  renderTopStats() {
    const {graphData} = this.props
    const stats = this.props.graphData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-gray-300' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border

      return (
        <div className={`px-8 w-1/2 my-4 lg:w-auto ${border}`} key={stat.name}>
          <div className="text-gray-500 dark:text-gray-400 text-xs font-bold tracking-wide uppercase">{stat.name}</div>
          <div className="my-1 flex justify-between items-center">
            <b className="text-2xl mr-4 dark:text-gray-100">{ this.renderTopStatNumber(stat) }</b>
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
    const endpoint = `/${encodeURIComponent(this.props.site.domain)}/visitors.csv${api.serializeQuery(this.props.query)}`

    return (
      <a href={endpoint} download>
        <svg className="feather w-4 h-5 absolute text-gray-700 dark:text-gray-300" style={{right: '2rem', top: '-2rem'}} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
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
      <div className="w-full relative bg-white dark:bg-gray-825 shadow-xl rounded mt-6 main-graph">
        { this.state.loading && <div className="loading pt-24 sm:pt-32 md:pt-48 mx-auto"><div></div></div> }
        { this.renderInner() }
      </div>
    )
  }
}
