import * as metrics from '../../reports/metrics'

export default function chooseMetrics({situation}) {
  if (situation.is_filtering_on_goal) {
    return [
      metrics.createTotalVisitors(),
      metrics.createVisitors({ renderLabel: (_query) => 'Conversions', width: 'w-28' }),
      metrics.createConversionRate()
    ]
  }

  if (situation.is_realtime_period) {
    return [
      metrics.createVisitors({ renderLabel: (_query) => 'Current visitors', width: 'w-36' }),
      metrics.createPercentage()
    ]
  }

  return [
    metrics.createVisitors({ renderLabel: (_query) => "Visitors" }),
    metrics.createPercentage(),
    metrics.createBounceRate(),
    metrics.createVisitDuration()
  ]
}
