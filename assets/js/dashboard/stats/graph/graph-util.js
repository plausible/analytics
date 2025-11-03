export const METRIC_LABELS = {
  visitors: 'Visitors',
  pageviews: 'Pageviews',
  events: 'Total Conversions',
  views_per_visit: 'Views per Visit',
  visits: 'Visits',
  bounce_rate: 'Bounce Rate',
  visit_duration: 'Visit Duration',
  conversions: 'Converted Visitors',
  conversion_rate: 'Conversion Rate',
  average_revenue: 'Average Revenue',
  total_revenue: 'Total Revenue',
  scroll_depth: 'Scroll Depth',
  time_on_page: 'Time on Page'
}

function plottable(dataArray) {
  return dataArray?.map((value) => {
    if (typeof value === 'object' && value !== null) {
      // Revenue metrics are returned as objects with a `value` property
      return value.value
    }

    return value || 0
  })
}

const buildComparisonDataset = function (comparisonPlot) {
  if (!comparisonPlot) return []

  return [
    {
      data: plottable(comparisonPlot),
      borderColor: 'rgb(199, 210, 254)',
      pointBackgroundColor: 'rgb(199, 210, 254)',
      pointHoverBackgroundColor: 'rgb(199, 210, 254)',
      yAxisID: 'yComparison'
    }
  ]
}

const buildDashedDataset = function (plot, presentIndex) {
  if (!presentIndex) return []

  const dashedPart = plot.slice(presentIndex - 1, presentIndex + 1)
  const dashedPlot = new Array(presentIndex - 1).concat(dashedPart)

  return [
    {
      data: plottable(dashedPlot),
      borderDash: [3, 3],
      borderColor: 'rgb(99, 102, 241)',
      pointHoverBackgroundColor: 'rgb(99, 102, 241)',
      yAxisID: 'y'
    }
  ]
}

const buildMainPlotDataset = function (plot, presentIndex) {
  const data = presentIndex ? plot.slice(0, presentIndex) : plot

  return [
    {
      data: plottable(data),
      borderColor: 'rgb(99, 102, 241)',
      pointBackgroundColor: 'rgb(99, 102, 241)',
      pointHoverBackgroundColor: 'rgb(99, 102, 241)',
      yAxisID: 'y'
    }
  ]
}

export const buildDataSet = (
  plot,
  comparisonPlot,
  present_index,
  ctx,
  label
) => {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300)
  var prev_gradient = ctx.createLinearGradient(0, 0, 0, 300)
  gradient.addColorStop(0, 'rgba(79, 70, 229, 0.15)')
  gradient.addColorStop(1, 'rgba(79, 70, 229, 0)')
  prev_gradient.addColorStop(0, 'rgba(79, 70, 229, 0.05)')
  prev_gradient.addColorStop(1, 'rgba(79, 70, 229, 0)')

  const defaultOptions = {
    label,
    borderWidth: 2,
    pointBorderColor: 'transparent',
    pointHoverRadius: 3,
    backgroundColor: gradient,
    fill: true
  }

  const dataset = [
    ...buildMainPlotDataset(plot, present_index),
    ...buildDashedDataset(plot, present_index),
    ...buildComparisonDataset(comparisonPlot)
  ]

  return dataset.map((item) => Object.assign(item, defaultOptions))
}

export function hasMultipleYears(graphData) {
  return (
    graphData.labels
      .filter((date) => typeof date === 'string')
      .map((date) => date.split('-')[0])
      .filter((value, index, list) => list.indexOf(value) === index).length > 1
  )
}
