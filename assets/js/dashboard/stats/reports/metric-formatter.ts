import { Metric } from '../../../types/query-api'
import { formatMoney } from '../../util/money'
import numberFormatter, { durationFormatter, percentageFormatter } from "../../util/number-formatter"

export type FormattableMetric = Metric | 'total_visitors' | 'exit_rate'

const MetricFormatter: Record<FormattableMetric, (value: any) => any> = {
  events: numberFormatter,
  pageviews: numberFormatter,
  total_visitors: numberFormatter,
  views_per_visit: numberFormatter,
  visitors: numberFormatter,
  visits: numberFormatter,

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
