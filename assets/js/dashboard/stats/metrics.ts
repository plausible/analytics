import { Metric } from '../../types/query-api'

export const getMetricLabel = (
  metric: Metric,
  { hasConversionGoalFilter }: { hasConversionGoalFilter: boolean }
): string => {
  switch (metric) {
    case 'visitors':
      return hasConversionGoalFilter ? 'Unique conversions' : 'Unique visitors'
    case 'events':
      return hasConversionGoalFilter ? 'Total conversions' : 'Total events'
    case 'visits':
      return 'Total visits'
    case 'pageviews':
      return 'Total pageviews'
    case 'views_per_visit':
      return 'Views per visit'
    case 'bounce_rate':
      return 'Bounce rate'
    case 'visit_duration':
      return 'Visit duration'
    case 'time_on_page':
      return 'Time on page'
    case 'scroll_depth':
      return 'Scroll depth'
    case 'conversion_rate':
      return 'Conversion rate'
    case 'total_revenue':
      return 'Total revenue'
    case 'average_revenue':
      return 'Average revenue'
    case 'percentage':
      return 'Percentage'
    case 'group_conversion_rate':
      return 'Conversion rate'
  }
}
