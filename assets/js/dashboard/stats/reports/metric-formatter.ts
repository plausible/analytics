import { Metric } from '../../../types/query-api'
import { formatMoney } from '../../util/money'
import numberShortFormatter, { durationFormatter, percentageFormatter } from "../../util/number-formatter"

export type FormattableMetric = Metric | 'total_visitors' | 'exit_rate'

const MetricFormatter: Record<FormattableMetric, (value: any) => any> = {
  events: numberShortFormatter,
  pageviews: numberShortFormatter,
  total_visitors: numberShortFormatter,
  views_per_visit: numberShortFormatter,
  visitors: numberShortFormatter,
  visits: numberShortFormatter,

  time_on_page: durationFormatter,
  visit_duration: durationFormatter,

  average_revenue: formatMoney,
  bounce_rate: percentageFormatter,
  conversion_rate: percentageFormatter,
  exit_rate: percentageFormatter,
  group_conversion_rate: percentageFormatter,
  percentage: percentageFormatter,
  total_revenue: formatMoney,
}

export default MetricFormatter
