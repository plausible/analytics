import { Metric } from '../../../types/query-api'
import { formatMoneyShort, formatMoneyLong } from '../../util/money'
import { numberShortFormatter, durationFormatter, percentageFormatter, numberLongFormatter } from "../../util/number-formatter"

export type FormattableMetric = Metric | 'total_visitors' | 'exit_rate'

export const MetricFormatterShort: Record<FormattableMetric, (value: any) => any> = {
  events: numberShortFormatter,
  pageviews: numberShortFormatter,
  total_visitors: numberShortFormatter,
  views_per_visit: numberShortFormatter,
  visitors: numberShortFormatter,
  visits: numberShortFormatter,

  time_on_page: durationFormatter,
  visit_duration: durationFormatter,

  bounce_rate: percentageFormatter,
  conversion_rate: percentageFormatter,
  exit_rate: percentageFormatter,
  group_conversion_rate: percentageFormatter,
  percentage: percentageFormatter,

  average_revenue: formatMoneyShort,
  total_revenue: formatMoneyShort,
}

export const MetricFormatterLong: Record<FormattableMetric, (value: any) => any> = {
  events: numberLongFormatter,
  pageviews: numberLongFormatter,
  total_visitors: numberLongFormatter,
  views_per_visit: numberLongFormatter,
  visitors: numberLongFormatter,
  visits: numberLongFormatter,

  time_on_page: durationFormatter,
  visit_duration: durationFormatter,

  bounce_rate: percentageFormatter,
  conversion_rate: percentageFormatter,
  exit_rate: percentageFormatter,
  group_conversion_rate: percentageFormatter,
  percentage: percentageFormatter,

  average_revenue: formatMoneyLong,
  total_revenue: formatMoneyLong,
}
