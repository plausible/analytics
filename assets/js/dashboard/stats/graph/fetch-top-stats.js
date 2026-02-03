import * as api from '../../api'
import { isComparisonEnabled } from '../../dashboard-time-periods'
import { createStatsQuery } from '../../stats-query'
import {
  hasConversionGoalFilter,
  hasPageFilter,
  isRealTimeDashboard
} from '../../util/filters'
import * as metrics from '../reports/metrics'

export async function fetchTopStats(site, dashboardState) {
  const metrics = chooseMetrics(site, dashboardState)

  let currentVisitorsPromise = null

  if (isRealTimeDashboard(dashboardState)) {
    currentVisitorsPromise = api.stats(
      site,
      createStatsQuery(
        { ...dashboardState, filters: [] },
        { metrics: ['visitors'] }
      )
    )
  }

  const topStatsQuery = constructTopStatsQuery(dashboardState, metrics)
  const topStatsPromise = api.stats(site, topStatsQuery)

  const [topStatsResponse, currentVisitorsResponse] = await Promise.all([
    topStatsPromise,
    currentVisitorsPromise
  ])

  return formatTopStatsData(topStatsResponse, currentVisitorsResponse, metrics)
}

function chooseMetrics(site, dashboardState) {
  const revenueMetrics =
    site.revenueGoals.length > 0
      ? [
          metrics.createTotalRevenue({ renderLabel: () => 'Total revenue' }),
          metrics.createAverageRevenue({ renderLabel: () => 'Average revenue' })
        ]
      : []

  if (
    isRealTimeDashboard(dashboardState) &&
    hasConversionGoalFilter(dashboardState)
  ) {
    return [
      metrics.createVisitors({
        renderLabel: () => 'Unique conversions (last 30 min)'
      }),
      metrics.createEvents({
        renderLabel: () => 'Total conversions (last 30 min)'
      })
    ]
  } else if (isRealTimeDashboard(dashboardState)) {
    return [
      metrics.createVisitors({
        renderLabel: () => 'Unique visitors (last 30 min)'
      }),
      metrics.createEvents({
        renderLabel: () => 'Total pageviews (last 30 min)'
      })
    ]
  } else if (hasConversionGoalFilter(dashboardState)) {
    return [
      metrics.createVisitors({ renderLabel: () => 'Unique conversions' }),
      metrics.createEvents({ renderLabel: () => 'Total conversions' })
    ]
      .concat(revenueMetrics)
      .concat([
        metrics.createConversionRate({ renderLabel: () => 'Conversion rate' })
      ])
  } else if (hasPageFilter(dashboardState) && dashboardState.with_imported) {
    // Note: Copied this condition over from the backend, but need to investigate why time_on_page
    // and bounce_rate cannot be queried with imported data. In any case, we should drop the metrics
    // on the backend, and simply request them here.
    return [
      metrics.createVisitors({ renderLabel: () => 'Unique visitors' }),
      metrics.createVisits({ renderLabel: () => 'Total visits' }),
      metrics.createPageviews({ renderLabel: () => 'Total pageviews' }),
      metrics.createScrollDepth()
    ]
  } else if (hasPageFilter(dashboardState)) {
    return [
      metrics.createVisitors({ renderLabel: () => 'Unique visitors' }),
      metrics.createVisits({ renderLabel: () => 'Total visits' }),
      metrics.createPageviews({ renderLabel: () => 'Total pageviews' }),
      metrics.createBounceRate(),
      metrics.createScrollDepth(),
      metrics.createTimeOnPage()
    ]
  } else {
    return [
      metrics.createVisitors({ renderLabel: () => 'Unique visitors' }),
      metrics.createVisits({ renderLabel: () => 'Total visits' }),
      metrics.createPageviews({ renderLabel: () => 'Total pageviews' }),
      metrics.createViewsPerVisit(),
      metrics.createBounceRate(),
      metrics.createVisitDuration()
    ]
  }
}

function constructTopStatsQuery(dashboardState, metrics) {
  const reportParams = {
    metrics: metrics.map((m) => m.key),
    include: { imports_meta: true }
  }

  let adjustedDashboardState = { ...dashboardState }

  if (
    !isComparisonEnabled(dashboardState.comparison) &&
    !isRealTimeDashboard(dashboardState)
  ) {
    adjustedDashboardState.comparison = 'previous_period'
  }

  if (isRealTimeDashboard(dashboardState)) {
    adjustedDashboardState.period = 'realtime_30m'
  }

  return createStatsQuery(adjustedDashboardState, reportParams)
}

function formatTopStatsData(
  topStatsResponse,
  currentVisitorsResponse,
  metrics
) {
  const { query, meta, results } = topStatsResponse

  let topStats = []

  if (currentVisitorsResponse) {
    topStats.push({
      metric: currentVisitorsResponse.query.metrics[0],
      value: currentVisitorsResponse.results[0].metrics[0],
      name: 'Current visitors',
      graphable: false
    })
  }

  for (let i = 0; i < query.metrics.length; i++) {
    let stat = {}

    stat.metric = query.metrics[i]
    stat.value = results[0].metrics[i]
    stat.name = metrics
      .find((inputMetric) => inputMetric.key === stat.metric)
      .renderLabel()
    stat.graphable = true
    stat.change = results[0].comparison?.change[i]
    stat.comparisonValue = results[0].comparison?.metrics[i]

    topStats.push(stat)
  }

  const [from, to] = query.date_range.map((d) => d.split('T')[0])

  const comparingFrom = query.comparison_date_range
    ? query.comparison_date_range[0].split('T')[0]
    : null
  const comparingTo = query.comparison_date_range
    ? query.comparison_date_range[1].split('T')[0]
    : null

  return { topStats, meta, from, to, comparingFrom, comparingTo }
}
