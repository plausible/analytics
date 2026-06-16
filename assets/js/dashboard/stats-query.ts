import { Metric } from './stats/metrics'
import {
  DashboardState,
  FilterOperator,
  FilterKey,
  FilterClause
} from './dashboard-state'
import { ComparisonMode, DashboardPeriod } from './dashboard-time-periods'
import { formatISO } from './util/date'
import * as apiTypes from '../types/query-api'
import { remapToApiFilters } from './util/filters'

export type FilterModifiers = { case_sensitive?: boolean }

export type ApiFilter =
  | [FilterOperator, FilterKey, FilterClause[]]
  | [FilterOperator, FilterKey, FilterClause[], FilterModifiers]

export type NonTimeDimension =
  | apiTypes.SimpleFilterDimensions
  | apiTypes.CustomPropertyFilterDimensions
  | apiTypes.GoalDimension

export type TimeDimension = apiTypes.TimeDimensions | 'time:minute'

export type Dimension = NonTimeDimension | TimeDimension

export type OrderByEntry = [Metric | NonTimeDimension, apiTypes.SortDirection]
export type OrderBy = OrderByEntry[]

export type DateRange = DashboardPeriod | [string, string]
export type RelativeDate = string | null

type IncludeCompare =
  | ComparisonMode.previous_period
  | ComparisonMode.year_over_year
  | string[]
  | null

export type QueryInclude = {
  imports: boolean
  imports_meta: boolean
  time_labels: boolean
  partial_time_labels: boolean
  compare: IncludeCompare
  compare_match_day_of_week: boolean
  present_index?: boolean
  empty_metrics?: boolean
}

export type ReportParams = {
  metrics: Metric[]
  dimensions: Dimension[]
  include?: Partial<QueryInclude>
  order_by?: OrderBy
  pagination?: apiTypes.Pagination
  alwaysOnFilters?: ApiFilter[]
}

export type StatsQuery = {
  date_range: DateRange
  relative_date: RelativeDate
  filters: ApiFilter[]
  dimensions: Dimension[]
  metrics: Metric[]
  include: QueryInclude
  order_by?: OrderBy | null
  pagination?: apiTypes.Pagination | null
}

export function addFilter(
  statsQuery: StatsQuery,
  filter: ApiFilter
): StatsQuery {
  return { ...statsQuery, filters: [...statsQuery.filters, filter] }
}

export function createStatsQuery(
  dashboardState: DashboardState,
  reportParams: ReportParams
): StatsQuery {
  return {
    date_range: createDateRange(dashboardState),
    relative_date: dashboardState.date ? formatISO(dashboardState.date) : null,
    dimensions: reportParams.dimensions || [],
    metrics: reportParams.metrics,
    filters: [
      ...remapToApiFilters(dashboardState.filters),
      ...(reportParams.alwaysOnFilters ?? [])
    ],
    order_by: reportParams.order_by || null,
    pagination: reportParams.pagination || null,
    include: {
      imports: dashboardState.with_imported,
      imports_meta: reportParams.include?.imports_meta || false,
      time_labels: reportParams.include?.time_labels || false,
      partial_time_labels: reportParams.include?.partial_time_labels || false,
      compare: createIncludeCompare(dashboardState),
      compare_match_day_of_week: dashboardState.match_day_of_week,
      empty_metrics: reportParams.include?.empty_metrics || false,
      present_index: reportParams.include?.present_index || false
    }
  }
}

export function createDateRange(dashboardState: DashboardState): DateRange {
  if (dashboardState.period === DashboardPeriod.custom) {
    return [formatISO(dashboardState.from), formatISO(dashboardState.to)]
  } else {
    return dashboardState.period
  }
}

function createIncludeCompare(dashboardState: DashboardState) {
  switch (dashboardState.comparison) {
    case ComparisonMode.custom:
      return [
        formatISO(dashboardState.compare_from),
        formatISO(dashboardState.compare_to)
      ]

    case ComparisonMode.previous_period:
      return ComparisonMode.previous_period

    case ComparisonMode.year_over_year:
      return ComparisonMode.year_over_year

    default:
      return null
  }
}
