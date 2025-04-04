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
      borderColor: 'rgba(60,70,110,0.2)',
      pointBackgroundColor: 'rgba(60,70,110,0.2)',
      pointHoverBackgroundColor: 'rgba(60, 70, 110)',
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
      borderColor: 'rgba(101,116,205)',
      pointHoverBackgroundColor: 'rgba(71, 87, 193)',
      yAxisID: 'y'
    }
  ]
}

const buildMainPlotDataset = function (plot, presentIndex) {
  const data = presentIndex ? plot.slice(0, presentIndex) : plot

  return [
    {
      data: plottable(data),
      borderColor: 'rgba(101,116,205)',
      pointBackgroundColor: 'rgba(101,116,205)',
      pointHoverBackgroundColor: 'rgba(71, 87, 193)',
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
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)')
  gradient.addColorStop(1, 'rgba(101,116,205, 0)')
  prev_gradient.addColorStop(0, 'rgba(101,116,205, 0.075)')
  prev_gradient.addColorStop(1, 'rgba(101,116,205, 0)')

  const defaultOptions = {
    label,
    borderWidth: 3,
    pointBorderColor: 'transparent',
    pointHoverRadius: 4,
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
