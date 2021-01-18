import Chart from 'chart.js'
import numberFormatter, {durationFormatter} from './dashboard/number-formatter'

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



export default {
  mounted() {
    this.handleEvent("visitor_graph:loaded", (payload) => {
      this.el.innerHTML = '<canvas id="main-graph-canvas" class="mt-4" width="1054" height="342"></canvas>'
      this.ctx = this.el.querySelector('canvas').getContext('2d');
      this.props = {darkTheme: false, query: {filters: {goal: null}}}
      console.log('HERE')
      this.regenerateChart(payload)
    })
  },

  onClick() {
    console.log('click')
  },

  regenerateChart(graphData) {
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
              return dateFormatter(graphData.interval, true)(data.xLabel)
            },
            beforeBody: function() {
              this.drawnLabels = {}
            },
            label: function(item) {
              const dataset = this._data.datasets[item.datasetIndex]
              if (!this.drawnLabels[dataset.label]) {
                this.drawnLabels[dataset.label] = true
                const pluralizedLabel = item.yLabel === 1 ? dataset.label.slice(0, -1) : dataset.label
                return ` ${item.yLabel} ${pluralizedLabel}`
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
}
