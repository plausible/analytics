import { Metric as PublicApiMetric } from '../../types/query-api'

export type Metric = PublicApiMetric | 'total_visitors' | 'exit_rate'

export type MetricSpec = { key: Metric; label: string }

export const VISITORS: MetricSpec = { key: 'visitors', label: 'Visitors' }
export const VISITORS_AS_CONVERSIONS: MetricSpec = {
  ...VISITORS,
  label: 'Conversions'
}
export const VISITORS_AS_CURRENT_VISITORS: MetricSpec = {
  ...VISITORS,
  label: 'Current visitors'
}
export const VISITORS_AS_UNIQUE_ENTRANCES: MetricSpec = {
  ...VISITORS,
  label: 'Unique entrances'
}
export const VISITORS_AS_UNIQUE_EXITS: MetricSpec = {
  ...VISITORS,
  label: 'Unique exits'
}
export const VISITORS_AS_UNIQUES: MetricSpec = {
  ...VISITORS,
  label: 'Uniques'
}
export const VISITORS_AS_UNIQUE_VISITORS: MetricSpec = {
  ...VISITORS,
  label: 'Unique visitors'
}
export const VISITORS_AS_UNIQUE_CONVERSIONS: MetricSpec = {
  ...VISITORS,
  label: 'Unique conversions'
}

export const VISITS: MetricSpec = { key: 'visits', label: 'Total visits' }
export const VISITS_AS_TOTAL_ENTRANCES: MetricSpec = {
  ...VISITS,
  label: 'Total entrances'
}
export const VISITS_AS_TOTAL_EXITS: MetricSpec = {
  ...VISITS,
  label: 'Total exits'
}

export const PAGEVIEWS: MetricSpec = { key: 'pageviews', label: 'Pageviews' }
export const PAGEVIEWS_AS_TOTAL_PAGEVIEWS: MetricSpec = {
  ...PAGEVIEWS,
  label: 'Total pageviews'
}

export const VIEWS_PER_VISIT: MetricSpec = {
  key: 'views_per_visit',
  label: 'Views per visit'
}
export const BOUNCE_RATE: MetricSpec = {
  key: 'bounce_rate',
  label: 'Bounce rate'
}
export const VISIT_DURATION: MetricSpec = {
  key: 'visit_duration',
  label: 'Visit duration'
}
export const TIME_ON_PAGE: MetricSpec = {
  key: 'time_on_page',
  label: 'Time on page'
}
export const SCROLL_DEPTH: MetricSpec = {
  key: 'scroll_depth',
  label: 'Scroll depth'
}

export const PERCENTAGE: MetricSpec = {
  key: 'percentage',
  label: 'Percentage'
}
export const PERCENTAGE_AS_PERCENT_SIGN: MetricSpec = {
  ...PERCENTAGE,
  label: '%'
}

export const EVENTS: MetricSpec = { key: 'events', label: 'Total events' }
export const EVENTS_AS_EVENTS: MetricSpec = { ...EVENTS, label: 'Events' }
export const EVENTS_AS_TOTAL: MetricSpec = { ...EVENTS, label: 'Total' }
export const EVENTS_AS_TOTAL_CONVERSIONS: MetricSpec = {
  ...EVENTS,
  label: 'Total conversions'
}

export const CONVERSION_RATE: MetricSpec = {
  key: 'conversion_rate',
  label: 'CR'
}
export const CONVERSION_RATE_AS_CONVERSION_RATE: MetricSpec = {
  ...CONVERSION_RATE,
  label: 'Conversion rate'
}
export const GROUP_CONVERSION_RATE: MetricSpec = {
  key: 'group_conversion_rate',
  label: 'CR'
}
export const GROUP_CONVERSION_RATE_AS_CONVERSION_RATE: MetricSpec = {
  ...GROUP_CONVERSION_RATE,
  label: 'Conversion rate'
}
export const TOTAL_REVENUE: MetricSpec = {
  key: 'total_revenue',
  label: 'Revenue'
}
export const TOTAL_REVENUE_AS_TOTAL_REVENUE: MetricSpec = {
  ...TOTAL_REVENUE,
  label: 'Total revenue'
}
export const AVERAGE_REVENUE: MetricSpec = {
  key: 'average_revenue',
  label: 'Average'
}
export const AVERAGE_REVENUE_AS_AVERAGE_REVENUE: MetricSpec = {
  ...AVERAGE_REVENUE,
  label: 'Average revenue'
}
export const TOTAL_VISITORS: MetricSpec = {
  key: 'total_visitors',
  label: 'Total visitors'
}
export const EXIT_RATE: MetricSpec = { key: 'exit_rate', label: 'Exit rate' }
