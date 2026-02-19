import { Metric } from '../types/query-api'
import { DashboardState, Filter } from './dashboard-state'
import { ComparisonMode, DashboardPeriod } from './dashboard-time-periods'
import { formatISO } from './util/date'
import { remapToApiFilters } from './util/filters'

type DateRange = DashboardPeriod | [string, string]
type IncludeCompare =
  | ComparisonMode.previous_period
  | ComparisonMode.year_over_year
  | string[]
  | null

type QueryInclude = {
  imports: boolean
  imports_meta: boolean
  time_labels: boolean
  compare: IncludeCompare
  compare_match_day_of_week: boolean
}

export type ReportParams = {
  metrics: Metric[]
  dimensions?: string[]
  include?: Partial<QueryInclude>
}

export type StatsQuery = {
  date_range: DateRange
  relative_date: string | null
  filters: Filter[]
  dimensions: string[]
  metrics: Metric[]
  include: QueryInclude
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
    filters: remapToApiFilters(dashboardState.filters),
    include: {
      imports: dashboardState.with_imported,
      imports_meta: reportParams.include?.imports_meta || false,
      time_labels: reportParams.include?.time_labels || false,
      compare: createIncludeCompare(dashboardState),
      compare_match_day_of_week: dashboardState.match_day_of_week
    }
  }
}

function createDateRange(dashboardState: DashboardState): DateRange {
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
