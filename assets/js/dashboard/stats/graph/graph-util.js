import numberFormatter, {durationFormatter} from '../../util/number-formatter'
import { parsePrefix } from '../../util/filters'

export function getGraphableMetrics(query, site) {
  const isRealtime = query.period === 'realtime'
  const goalFilter = query.filters.goal
  const pageFilter = query.filters.page
  
  if (isRealtime && goalFilter) {
    return ["visitors"]
  } else if (isRealtime) {
    return ["visitors", "pageviews"]
  } else if (goalFilter && canGraphRevenueMetrics(goalFilter, site)) {
    return ["visitors", "events", "average_revenue", "total_revenue", "conversion_rate"]
  } else if (goalFilter) {
    return ["visitors", "events", "conversion_rate"]
  } else if (pageFilter) {
    return ["visitors", "visits", "pageviews", "bounce_rate", "time_on_page"]
  } else {
    return ["visitors", "visits", "pageviews", "views_per_visit", "bounce_rate", "visit_duration"]
  }
}

// Revenue metrics can only be graphed if:
//   * The query is filtered by at least one revenue goal
//   * All revenue goals in filter have the same currency
function canGraphRevenueMetrics(goalFilter, site) {
  const goalsInFilter = parsePrefix(goalFilter).values

  const revenueGoalsInFilter = site.revenueGoals.filter((rg) => {
    return goalsInFilter.includes(rg.event_name)
  })
  
  const singleCurrency = revenueGoalsInFilter.every((rg) => {
    return rg.currency === revenueGoalsInFilter[0].currency
  })

  return revenueGoalsInFilter.length > 0 && singleCurrency
}

export const METRIC_LABELS = {
  'visitors': 'Visitors',
  'pageviews': 'Pageviews',
  'events': 'Total Conversions',
  'views_per_visit': 'Views per Visit',
  'visits': 'Visits',
  'bounce_rate': 'Bounce Rate',
  'visit_duration': 'Visit Duration',
  'conversions': 'Converted Visitors',
  'conversion_rate': 'Conversion Rate',
  'average_revenue': 'Average Revenue',
  'total_revenue': 'Total Revenue',
}

export const METRIC_FORMATTER = {
  'visitors': numberFormatter,
  'pageviews': numberFormatter,
  'events': numberFormatter,
  'visits': numberFormatter,
  'views_per_visit': (number) => (number),
  'bounce_rate': (number) => (`${number}%`),
  'visit_duration': durationFormatter,
  'conversions': numberFormatter,
  'conversion_rate': (number) => (`${number}%`),
  'total_revenue': numberFormatter,
  'average_revenue': numberFormatter,
}

const buildComparisonDataset = function(comparisonPlot) {
  if (!comparisonPlot) return []

  return [{
    data: comparisonPlot,
    borderColor: 'rgba(60,70,110,0.2)',
    pointBackgroundColor: 'rgba(60,70,110,0.2)',
    pointHoverBackgroundColor: 'rgba(60, 70, 110)',
    yAxisID: 'yComparison',
  }]
}

const buildDashedDataset = function(plot, presentIndex) {
  if (!presentIndex) return []

  const dashedPart = plot.slice(presentIndex - 1, presentIndex + 1);
  const dashedPlot = (new Array(presentIndex - 1)).concat(dashedPart)

  return [{
    data: dashedPlot,
    borderDash: [3, 3],
    borderColor: 'rgba(101,116,205)',
    pointHoverBackgroundColor: 'rgba(71, 87, 193)',
    yAxisID: 'y',
  }]
}

const buildMainPlotDataset = function(plot, presentIndex) {
  const data = presentIndex ? plot.slice(0, presentIndex) : plot

  return [{
    data: data,
    borderColor: 'rgba(101,116,205)',
    pointBackgroundColor: 'rgba(101,116,205)',
    pointHoverBackgroundColor: 'rgba(71, 87, 193)',
    yAxisID: 'y',
  }]
}

export const buildDataSet = (plot, comparisonPlot, present_index, ctx, label) => {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  var prev_gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');
  prev_gradient.addColorStop(0, 'rgba(101,116,205, 0.075)');
  prev_gradient.addColorStop(1, 'rgba(101,116,205, 0)');

  const defaultOptions = { label, borderWidth: 3, pointBorderColor: "transparent", pointHoverRadius: 4, backgroundColor: gradient, fill: true }

  const dataset = [
    ...buildMainPlotDataset(plot, present_index),
    ...buildDashedDataset(plot, present_index),
    ...buildComparisonDataset(comparisonPlot)
  ]

  return dataset.map((item) => Object.assign(item, defaultOptions))
}
