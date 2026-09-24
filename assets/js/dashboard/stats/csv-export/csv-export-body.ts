import { DashboardState } from '../../dashboard-state'
import {
  ApiFilter,
  createDateRange,
  DateRange,
  TimeDimension,
  QueryInclude,
  RelativeDate
} from '../../stats-query'
import { formatISO } from '../../util/date'
import {
  hasConversionGoalFilter,
  hasEventFilters,
  hasPageFilter,
  remapToApiFilters
} from '../../util/filters'
import { Interval } from '../graph/intervals'
import { Metric } from '../metrics'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportConfig,
  BreakdownReportKey,
  getCustomPropsMetrics
} from '../reports/reports-config'

const BREAKDOWN_CSV_REPORTS = {
  'pages.csv': BreakdownReportKey.pages,
  'entry_pages.csv': BreakdownReportKey.entryPages,
  'exit_pages.csv': BreakdownReportKey.exitPages,
  'browsers.csv': BreakdownReportKey.browsers,
  'browser_versions.csv': BreakdownReportKey.browserVersions,
  'operating_systems.csv': BreakdownReportKey.operatingSystems,
  'operating_system_versions.csv': BreakdownReportKey.operatingSystemVersions,
  'devices.csv': BreakdownReportKey.screenSizes,
  'channels.csv': BreakdownReportKey.channels,
  'sources.csv': BreakdownReportKey.sources,
  'referrers.csv': BreakdownReportKey.referrers,
  'utm_mediums.csv': BreakdownReportKey.utmMediums,
  'utm_sources.csv': BreakdownReportKey.utmSources,
  'utm_campaigns.csv': BreakdownReportKey.utmCampaigns,
  'utm_contents.csv': BreakdownReportKey.utmContents,
  'utm_terms.csv': BreakdownReportKey.utmTerms,
  'countries.csv': BreakdownReportKey.countries,
  'regions.csv': BreakdownReportKey.regions,
  'cities.csv': BreakdownReportKey.cities,
  'conversions.csv': BreakdownReportKey.goals
}
type CsvFilename =
  | 'visitors.csv'
  | 'custom_props.csv'
  | keyof typeof BREAKDOWN_CSV_REPORTS

type CsvReportParams = {
  dimensions: [TimeDimension] | BreakdownReportConfig['dimensions']
  metrics: Metric[]
  always_on_filters?: BreakdownReportConfig['alwaysOnFilters']
}
type CsvReportsConfig = Record<CsvFilename, CsvReportParams>

export type CsvExportRequestBody = {
  date_range: DateRange
  relative_date: RelativeDate
  filters: ApiFilter[]
  include: Pick<QueryInclude, 'imports'>
  reports: CsvReportsConfig
}

const DEFAULT_VISITORS_CSV_METRICS: Metric[] = [
  'visitors',
  'pageviews',
  'visits',
  'views_per_visit',
  'bounce_rate',
  'visit_duration'
]
const PAGE_FILTERED_VISITORS_CSV_METRICS: Metric[] = [
  'visitors',
  'pageviews',
  'visits',
  'bounce_rate',
  'time_on_page',
  'scroll_depth'
]
const GOAL_FILTERED_VISITORS_CSV_METRICS: Metric[] = [
  'visitors',
  'events',
  'conversion_rate'
]

function csvDimensions(
  reportKey: BreakdownReportKey
): CsvReportParams['dimensions'] {
  switch (reportKey) {
    case BreakdownReportKey.countries:
      return ['visit:country_name']
    case BreakdownReportKey.regions:
      return ['visit:region_name']
    case BreakdownReportKey.cities:
      return ['visit:city_name']
    default:
      return BREAKDOWN_REPORTS[reportKey].dimensions
  }
}

export function createCsvExportRequestBody(
  dashboardState: DashboardState,
  graphInterval: Interval
): CsvExportRequestBody {
  const isGoalFilter = hasConversionGoalFilter(dashboardState)
  const isPageFilter = hasPageFilter(dashboardState)
  const isEventFilter = hasEventFilters(dashboardState)

  const reports: CsvReportsConfig = {
    'visitors.csv': {
      dimensions: [`time:${graphInterval}`],
      metrics: isGoalFilter
        ? GOAL_FILTERED_VISITORS_CSV_METRICS
        : isPageFilter
          ? PAGE_FILTERED_VISITORS_CSV_METRICS
          : DEFAULT_VISITORS_CSV_METRICS
    },
    'custom_props.csv': {
      dimensions: ['event:props:*'],
      metrics: getCustomPropsMetrics({
        hasConversionGoalFilter: isGoalFilter,
        isRevenueAvailable: false
      })
    },
    ...Object.entries(BREAKDOWN_CSV_REPORTS).reduce(
      (acc, [filename, reportKey]) => {
        const config = BREAKDOWN_REPORTS[reportKey]
        acc[filename as keyof typeof BREAKDOWN_CSV_REPORTS] = {
          dimensions: csvDimensions(reportKey),
          always_on_filters: config.alwaysOnFilters,
          metrics: config.getMetrics({
            isCsv: true,
            hasConversionGoalFilter: isGoalFilter,
            hasEventFilters: isEventFilter
          })
        }
        return acc
      },
      {} as Omit<CsvReportsConfig, 'visitors.csv' | 'custom_props.csv'>
    )
  }

  return {
    date_range: createDateRange(dashboardState),
    relative_date: dashboardState.date ? formatISO(dashboardState.date) : null,
    filters: remapToApiFilters(dashboardState.filters),
    include: { imports: dashboardState.with_imported },
    reports: reports
  }
}
