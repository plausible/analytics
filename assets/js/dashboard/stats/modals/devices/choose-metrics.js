import { hasGoalFilter, isRealTimeDashboard } from "../../../util/filters";
import * as metrics from '../../reports/metrics'

export default function chooseMetrics(query) {
  if (hasGoalFilter(query)) {
    return [
      metrics.createTotalVisitors(),
      metrics.createVisitors({ renderLabel: () => 'Conversions', width: 'w-28' }),
      metrics.createConversionRate()
    ]
  }

  if (isRealTimeDashboard(query)) {
    return [
      metrics.createVisitors({ renderLabel: () => 'Current visitors', width: 'w-36' }),
      metrics.createPercentage()
    ]
  }

  return [
    metrics.createVisitors({ renderLabel: () => "Visitors" }),
    metrics.createPercentage(),
    metrics.createBounceRate(),
    metrics.createVisitDuration()
  ]
}
