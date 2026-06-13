import { Metric } from './metrics'

const SORTABLE: Metric[] = [
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
