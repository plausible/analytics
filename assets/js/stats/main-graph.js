export function renderMainGraph(graphData) {
  const extraClass = graphData.interval === 'hour' ? '' : 'cursor-pointer'

  const TEMPLATE = `
    <div class="border-b border-grey-light flex p-4">
      <div class="border-r border-grey-light pl-2 pr-10">
        <div class="text-grey-dark text-sm font-bold tracking-wide">UNIQUE VISITORS</div>
        <div class="mt-2 flex items-center justify-between" id="visitors">
          <b class="text-2xl" title="${graphData.unique_visitors.toLocaleString()}">${numberFormatter(graphData.unique_visitors)}</b>
        </div>
      </div>
      <div class="px-10">
        <div class="text-grey-dark text-sm font-bold tracking-wide">TOTAL PAGEVIEWS</div>
        <div class="mt-2 flex items-center justify-between" id="pageviews">
          <b class="text-2xl" title="${graphData.pageviews.toLocaleString()}">${numberFormatter(graphData.pageviews)}</b>
        </div>
      </div>
    </div>
    <div class="p-4">
      <canvas id="main-graph-canvas" class="mt-4 ${extraClass}" width="1054" height="329"></canvas>
    </div>
  `

  const mainGraphDiv = document.getElementById('main-graph')
  mainGraphDiv.innerHTML = TEMPLATE
  drawGraph(graphData)
  return graphData
}

export function renderComparisons(comparisons) {
  const visitorsDiv = document.getElementById('visitors')
  const pageviewsDiv = document.getElementById('pageviews')

  if (comparisons.change_pageviews && comparisons.change_visitors) {
    const formattedChangeVisitors = numberFormatter(Math.abs(comparisons.change_visitors))

    if (comparisons.change_visitors >= 0) {
      visitorsDiv.innerHTML +=`
        <span class="bg-green-lightest text-green-dark px-2 py-1 text-xs font-bold rounded">&uarr; ${formattedChangeVisitors}%</span>
      `
    } else if (comparisons.change_visitors < 0) {
      visitorsDiv.innerHTML +=`
        <span class="bg-red-lightest text-red-dark px-2 py-1 text-xs font-bold rounded">&darr; ${formattedChangeVisitors}%</span>
      `
    }

    const formattedChangePageviews = numberFormatter(Math.abs(comparisons.change_pageviews))

    if (comparisons.change_pageviews >= 0) {
      pageviewsDiv.innerHTML +=`
        <span class="bg-green-lightest text-green-dark px-2 py-1 text-xs font-bold rounded">&uarr; ${formattedChangePageviews}%</span>
      `
    } else if (comparisons.change_pageviews < 0) {
      pageviewsDiv.innerHTML +=`
        <span class="bg-red-lightest text-red-dark px-2 py-1 text-xs font-bold rounded">&darr; ${formattedChangePageviews}%</span>
      `
    }
  } else {
    visitorsDiv.innerHTML +=`
      <span class="bg-grey-lightest text-grey-dark px-2 py-1 text-xs font-bold rounded">N/A</span>
    `
    pageviewsDiv.innerHTML +=`
      <span class="bg-grey-lightest text-grey-dark px-2 py-1 text-xs font-bold rounded">N/A</span>
    `
  }
}

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

function drawGraph(graphData) {
  var ctx = document.getElementById("main-graph-canvas").getContext('2d');

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

const THOUSAND = 1000
const HUNDRED_THOUSAND = 100000
const MILLION = 1000000
const HUNDRED_MILLION = 100000000

function numberFormatter(num) {
  if (num >= THOUSAND && num < MILLION) {
    const thousands = num / THOUSAND
    if (thousands === Math.floor(thousands) || num >= HUNDRED_THOUSAND) {
      return Math.floor(thousands) + 'k'
    } else {
      return (Math.floor(thousands * 10) / 10) + 'k'
    }
  } else if (num >= MILLION && num < HUNDRED_MILLION) {
    const millions = num / MILLION
    if (millions === Math.floor(millions)) {
      return Math.floor(millions) + 'm'
    } else {
      return (Math.floor(millions * 10) / 10) + 'm'
    }
  } else {
    return num
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
      var hours = date.getUTCHours();
      var ampm = hours >= 12 ? 'pm' : 'am';
      hours = hours % 12;
      hours = hours ? hours : 12; // the hour '0' should be '12'
      return hours + ampm;
    }
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
