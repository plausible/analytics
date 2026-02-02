import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../../util/filters'
import { revenueAvailable } from '../../../dashboard-state'
import * as metrics from '../../reports/metrics'

export default function chooseMetrics(dashboardState, site) {
  /*global BUILD_EXTRA*/
  const showRevenueMetrics =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  if (hasConversionGoalFilter(dashboardState)) {
    return [
      metrics.createTotalVisitors(),
      metrics.createVisitors({
        renderLabel: (_query) => 'Conversions',
        width: 'w-32 md:w-28'
      }),
      metrics.createConversionRate(),
      showRevenueMetrics && metrics.createTotalRevenue(),
      showRevenueMetrics && metrics.createAverageRevenue()
    ].filter((metric) => !!metric)
  }

  if (
    isRealTimeDashboard(dashboardState) &&
    !hasConversionGoalFilter(dashboardState)
  ) {
    return [
      metrics.createVisitors({
        renderLabel: (_query) => 'Current visitors',
        width: 'w-32'
      }),
      metrics.createPercentage()
    ]
  }

  return [
    metrics.createVisitors({ renderLabel: (_query) => 'Visitors' }),
    metrics.createPercentage(),
    metrics.createBounceRate(),
    metrics.createVisitDuration()
  ]
}
