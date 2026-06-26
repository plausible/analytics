import { Metric as PublicApiMetric } from '../../types/query-api'

export type Metric = PublicApiMetric | 'total_visitors' | 'exit_rate'

const SORTABLE = [
  'visitors',
  'visits',
  'pageviews',
  'views_per_visit',
  'bounce_rate',
  'visit_duration',
  'events',
  'percentage',
  'conversion_rate',
  'group_conversion_rate',
  'time_on_page',
  'total_revenue',
  'average_revenue',
  'scroll_depth',
  'exit_rate'
]

export const isSortable = (metric: Metric): boolean => {
  return SORTABLE.includes(metric)
}

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
    case 'total_visitors':
      return 'Total visitors'
    case 'exit_rate':
      return 'Exit rate'
  }
}

export const getBreakdownMetricLabel = (
  metric: Metric,
  {
    hasConversionGoalFilter,
    isRealtime,
    dimensions
  }: {
    hasConversionGoalFilter: boolean
    isRealtime: boolean
    dimensions: string[]
  }
): string => {
  if (dimensions.includes('visit:entry_page')) {
    return getEntryPagesBreakdownMetricLabel(metric, {
      hasConversionGoalFilter,
      isRealtime
    })
  }
  if (dimensions.includes('visit:exit_page')) {
    return getExitPagesBreakdownMetricLabel(metric, {
      hasConversionGoalFilter,
      isRealtime
    })
  }
  switch (dimensions[0]) {
    case 'event:goal':
      return getConversionsBreakdownMetricLabel(metric)
    default: {
      if (dimensions[0]?.startsWith('event:props:')) {
        return getCustomPropsBreakdownMetricLabel(metric)
      }
      return getDefaultBreakdownMetricLabel(metric, {
        hasConversionGoalFilter,
        isRealtime
      })
    }
  }
}

const getCustomPropsBreakdownMetricLabel = (metric: Metric): string => {
  switch (metric) {
    case 'visitors':
      return 'Visitors'
    case 'events':
      return 'Events'
    case 'percentage':
      return '%'
    default:
      return getDefaultBreakdownMetricLabel(metric, {
        hasConversionGoalFilter: false,
        isRealtime: false
      })
  }
}

const getEntryPagesBreakdownMetricLabel = (
  metric: Metric,
  {
    hasConversionGoalFilter,
    isRealtime
  }: { hasConversionGoalFilter: boolean; isRealtime: boolean }
): string => {
  if (metric === 'visitors' && !hasConversionGoalFilter && !isRealtime) {
    return 'Unique entrances'
  }
  if (metric === 'visits' && !hasConversionGoalFilter && !isRealtime) {
    return 'Total entrances'
  }

  return getDefaultBreakdownMetricLabel(metric, {
    hasConversionGoalFilter,
    isRealtime
  })
}

const getExitPagesBreakdownMetricLabel = (
  metric: Metric,
  {
    hasConversionGoalFilter,
    isRealtime
  }: { hasConversionGoalFilter: boolean; isRealtime: boolean }
): string => {
  if (metric === 'visitors' && !hasConversionGoalFilter && !isRealtime) {
    return 'Unique exits'
  }
  if (metric === 'visits' && !hasConversionGoalFilter && !isRealtime) {
    return 'Total exits'
  }

  return getDefaultBreakdownMetricLabel(metric, {
    hasConversionGoalFilter,
    isRealtime
  })
}

const getConversionsBreakdownMetricLabel = (metric: Metric): string => {
  switch (metric) {
    case 'visitors':
      return 'Uniques'
    case 'events':
      return 'Total'
    default:
      return getDefaultBreakdownMetricLabel(metric, {
        hasConversionGoalFilter: false,
        isRealtime: false
      })
  }
}

const getDefaultBreakdownMetricLabel = (
  metric: Metric,
  {
    hasConversionGoalFilter,
    isRealtime
  }: { hasConversionGoalFilter: boolean; isRealtime: boolean }
): string => {
  switch (metric) {
    case 'visitors':
      return hasConversionGoalFilter
        ? 'Conversions'
        : isRealtime
          ? 'Current visitors'
          : 'Visitors'
    case 'group_conversion_rate':
      return 'CR'
    case 'conversion_rate':
      return 'CR'
    case 'average_revenue':
      return 'Average'
    case 'total_revenue':
      return 'Revenue'
    case 'pageviews':
      return 'Pageviews'
    default:
      return getMetricLabel(metric, { hasConversionGoalFilter })
  }
}
