/** @format */

import { Metric } from '../../../types/query-api'
import { formatMoneyShort, formatMoneyLong } from '../../util/money'
import {
  numberShortFormatter,
  durationFormatter,
  percentageFormatter,
  numberLongFormatter,
  nullable
} from '../../util/number-formatter'

export type FormattableMetric =
  | Metric
  | 'current_visitors'
  | 'exit_rate'
  | 'conversions'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type ValueType = any

export const MetricFormatterShort: Record<
  FormattableMetric,
  (value: ValueType) => string
> = {
  events: nullable(numberShortFormatter),
  pageviews: numberShortFormatter,
  current_visitors: numberShortFormatter,
  views_per_visit: numberShortFormatter,
  visitors: numberShortFormatter,
  visits: numberShortFormatter,

  conversions: numberShortFormatter,

  time_on_page: durationFormatter,
  visit_duration: durationFormatter,

  bounce_rate: percentageFormatter,
  conversion_rate: percentageFormatter,
  scroll_depth: percentageFormatter,
  exit_rate: percentageFormatter,
  group_conversion_rate: percentageFormatter,
  percentage: percentageFormatter,

  average_revenue: formatMoneyShort,
  total_revenue: formatMoneyShort
}

export const MetricFormatterLong: Record<
  FormattableMetric,
  (value: ValueType) => string
> = {
  events: nullable(numberLongFormatter),
  pageviews: numberLongFormatter,
  current_visitors: numberShortFormatter,
  views_per_visit: numberLongFormatter,
  visitors: numberLongFormatter,
  visits: numberLongFormatter,

  conversions: numberLongFormatter,

  time_on_page: durationFormatter,
  visit_duration: durationFormatter,

  bounce_rate: percentageFormatter,
  conversion_rate: percentageFormatter,
  scroll_depth: percentageFormatter,
  exit_rate: percentageFormatter,
  group_conversion_rate: percentageFormatter,
  percentage: percentageFormatter,

  average_revenue: formatMoneyLong,
  total_revenue: formatMoneyLong
}
