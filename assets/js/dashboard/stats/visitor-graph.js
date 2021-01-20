import React from 'react';
import { withRouter } from 'react-router-dom'
import Chart from 'chart.js'
import { eventName, navigateToQuery } from '../query'
import numberFormatter, { durationFormatter } from '../number-formatter'
import * as api from '../api'
import { ThemeContext } from '../theme-context'

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
        label: label,
        data: _plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
      },
      {
        label: label,
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
        label: label,
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
      label: label,
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

function dateFormatter(interval, longForm) {
  return function (isoDate) {
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
  }

  regenerateChart() {
    const { graphData } = this.props
    this.ctx = document.getElementById("main-graph-canvas").getContext('2d');
    const label = this.props.query.filters.goal ? 'Converted visitors' : graphData.interval === 'minute' ? 'Pageviews' : 'Visitors'
    const dataSet = buildDataSet(graphData.plot, graphData.present_index, this.ctx, label)
    const prev_dataSet = buildDataSet(graphData.prev_plot, false, this.ctx, label, true)

    return new Chart(this.ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: [...dataSet, ...prev_dataSet]
      },
      options: {
        animation: false,
        legend: { display: false },
        responsive: true,
        elements: { line: { tension: 0.1 }, point: { radius: 0 } },
        onClick: this.onClick.bind(this),
        hover: {
          mode: 'index',
          intersect: false
        },
        tooltips: {
          enabled: false,
          mode: 'index',
          position: 'average',
          intersect: false,
          custom: function (tooltipModel) {
            // Canvas Offset from 0,0
            const offset = this._chart.canvas.getBoundingClientRect();
            // Tooltip Element
            let tooltipEl = document.getElementById('chartjs-tooltip');

            // Create element on first render
            if (!tooltipEl) {
              tooltipEl = document.createElement('div');
              tooltipEl.id = 'chartjs-tooltip';
              document.body.appendChild(tooltipEl);
            }

            if (tooltipEl && offset && window.innerWidth < 768) {
              tooltipEl.style.top = offset.y + offset.height + window.pageYOffset + 'px'
              tooltipEl.style.left = offset.x + window.pageXOffset + 'px'
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
              // Don't render if we only have one dataset available (this means the point is in the future)
              if (bodyLines.length == 1) {
                tooltipEl.style.opacity = 0;
                return;
              }

              const data = tooltipModel.dataPoints[0]
              const prev_data = tooltipModel.dataPoints.slice(-1)[0]
              const label = graphData.labels[data.index]
              const prev_label = graphData.prev_labels[prev_data.index]
              const point = data.yLabel || 0
              const prev_point = prev_data.yLabel || 0
              const pct_change = point === prev_point ? 0 : prev_point === 0 ? 100 : parseFloat(((point - prev_point) / prev_point * 100).toFixed(1))

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
                    <span class='font-bold mr-4 text-lg'>${bodyLines[0][0].split(':')[0]}</span>
                    ${graphData.interval === 'minute' ? '' : renderComparison(pct_change)}
                </div>
                <div class='flex flex-col'>
                  <div class='flex flex-row justify-between items-center'>
                    <span class='flex items-center mr-4'>
                      <div class='w-3 h-3 mr-1 rounded-full' style='background-color: rgba(101,116,205)'></div>
                      <span>${renderLabel()}</span>
                    </span>
                    <span>${numberFormatter(point)}</span>
                  </div>
                  ${graphData.interval === 'minute' ? '' : `
                    <div class='flex flex-row justify-between items-center mt-1'>
                      <span class='flex items-center mr-4'>
                        <div class='w-3 h-3 mr-1 rounded-full' style='background-color: rgba(166,187,210,0.5)'></div>
                        <span>${renderLabel(true)}</span>
                      </span>
                      <span>${numberFormatter(prev_point)}</span>
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

  repositionTooltip(e) {
    const tooltipEl = document.getElementById('chartjs-tooltip');
    if (tooltipEl && window.innerWidth >= 768) {
      tooltipEl.style.top = e.clientY + window.pageYOffset + 'px'
      tooltipEl.style.left = e.clientX + window.pageXOffset + 'px'
    }
  }

  componentDidMount() {
    this.chart = this.regenerateChart();

    // Having the tooltip follow the mouse is much more intuitive
    window.addEventListener('mousemove', this.repositionTooltip);
  }

  componentDidUpdate(prevProps) {
    if (JSON.stringify(this.props.graphData) !== JSON.stringify(prevProps.graphData)) {
      this.chart = this.regenerateChart();
      this.chart.update();
    }

    if (prevProps.darkTheme !== this.props.darkTheme) {
      this.chart = this.regenerateChart();
      this.chart.update();
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

  onClick(e) {
    const element = this.chart.getElementsAtEventForMode(e, 'index', { intersect: false })[0]
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
      return <span className='text-sm flex dark:text-gray-300'><div className={color + ' transform -rotate-90'}>&#10132;</div>{formattedComparison}%</span>
    }
    if (comparison < 0) {
      const color = name === 'Bounce rate' ? 'text-green-500' : 'text-red-400'
      return <span className='text-sm flex dark:text-gray-300'><div className={color + ' transform rotate-90'}>&#10132;</div>{formattedComparison}%</span>
    }
    if (comparison === 0) {
      return <span className='text-sm text-gray-700 dark:text-gray-300'>&#12336; 0%</span>
    }
  }

  renderTopStatNumber(stat) {
    if (stat.name === 'Visit duration') {
      return durationFormatter(stat.count)
    } else if (typeof (stat.count) == 'number') {
      return numberFormatter(stat.count)
    } else {
      return stat.percentage + '%'
    }
  }

  renderTopStats() {
    const { graphData } = this.props
    const stats = this.props.graphData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-gray-300' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border

      return (
        <div className={`px-8 w-1/2 my-4 lg:w-auto ${border}`} key={stat.name}>
          <div className="text-gray-500 dark:text-gray-400 text-xs font-bold tracking-wide uppercase">{stat.name}</div>
          <div className="my-1 flex justify-between items-center">
            <b className="text-2xl mr-4 dark:text-gray-100">{this.renderTopStatNumber(stat)}</b>
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
    const endpoint = `/${encodeURIComponent(this.props.site.domain)}/visitors.csv${api.serializeQuery(this.props.query)}`

    return (
      <a href={endpoint} download>
        <svg className="feather w-4 h-5 absolute text-gray-700 dark:text-gray-300 cursor-pointer" style={{ right: '2rem', top: '-2rem' }} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
      </a>
    )
  }

  render() {
    const extraClass = this.props.graphData.interval === 'hour' ? '' : 'cursor-pointer'

    return (
      <React.Fragment>
        <div className="flex flex-wrap">
          {this.renderTopStats()}
        </div>
        <div className="px-2 relative">
          {this.downloadLink()}
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
    this.state = { loading: true }
  }

  componentDidMount() {
    this.fetchGraphData()
    if (this.props.timer) this.props.timer.onTick(this.fetchGraphData.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({ loading: true, graphData: null })
      this.fetchGraphData()
    }
  }

  fetchGraphData() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/main-graph`, this.props.query)
      .then((res) => {
        this.setState({ loading: false, graphData: res })
        return res
      })
  }

  renderInner() {
    if (this.state.graphData) {
      return (
        <ThemeContext.Consumer>
          {theme => (
            <LineGraph graphData={this.state.graphData} site={this.props.site} query={this.props.query} darkTheme={theme} />
          )}
        </ThemeContext.Consumer>
      )
    }
  }

  render() {
    return (
      <div className="w-full relative bg-white dark:bg-gray-825 shadow-xl rounded mt-6 main-graph">
        { this.state.loading && <div className="loading pt-24 sm:pt-32 md:pt-48 mx-auto"><div></div></div>}
        { this.renderInner()}
      </div>
    )
  }
}
