import { ApiFilter, NonTimeDimension } from '../../stats-query'
import {
  AVERAGE_REVENUE,
  BOUNCE_RATE,
  EXIT_RATE,
  GROUP_CONVERSION_RATE,
  PAGEVIEWS,
  PERCENTAGE,
  SCROLL_DEPTH,
  TIME_ON_PAGE,
  TOTAL_REVENUE,
  TOTAL_VISITORS,
  VISIT_DURATION,
  VISITORS,
  VISITORS_AS_CONVERSIONS,
  VISITORS_AS_CURRENT_VISITORS,
  VISITORS_AS_UNIQUE_ENTRANCES,
  VISITORS_AS_UNIQUE_EXITS,
  VISITS_AS_TOTAL_ENTRANCES,
  VISITS_AS_TOTAL_EXITS
} from '../metrics'
import { BreakdownMetric } from '../breakdowns'

export type MetricContext = {
  hasConversionGoalFilter: boolean
  isRealtime?: boolean
  isCsv?: boolean
  isDetailed?: boolean
  isRevenueAvailable?: boolean
  hasEventFilters?: boolean
}

export type BreakdownReportConfig = {
  dimensions: [NonTimeDimension, ...NonTimeDimension[]]
  getMetrics: (context: MetricContext) => BreakdownMetric[]
  detailsTitle: string
  detailsPath: string
  dimensionLabel: string
  alwaysOnFilters?: ApiFilter[]
}

export enum BreakdownReportKey {
  'pages' = 'pages',
  'entryPages' = 'entryPages',
  'exitPages' = 'exitPages',
  'browsers' = 'browsers',
  'browserVersions' = 'browserVersions',
  'operatingSystems' = 'operatingSystems',
  'operatingSystemVersions' = 'operatingSystemVersions',
  'screenSizes' = 'screenSizes',
  'channels' = 'channels',
  'sources' = 'sources',
  'referrers' = 'referrers',
  'utmMediums' = 'utmMediums',
  'utmSources' = 'utmSources',
  'utmCampaigns' = 'utmCampaigns',
  'utmContents' = 'utmContents',
  'utmTerms' = 'utmTerms',
  'countries' = 'countries',
  'regions' = 'regions',
  'cities' = 'cities'
}

export const BREAKDOWN_REPORTS: Record<
  BreakdownReportKey,
  BreakdownReportConfig
> = {
  [BreakdownReportKey.pages]: {
    dimensions: ['event:page'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv)
        return [VISITORS, PAGEVIEWS, BOUNCE_RATE, TIME_ON_PAGE, SCROLL_DEPTH]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [
          VISITORS,
          PERCENTAGE,
          PAGEVIEWS,
          BOUNCE_RATE,
          TIME_ON_PAGE,
          SCROLL_DEPTH
        ]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Top pages',
    detailsPath: 'pages',
    dimensionLabel: 'Page'
  },
  [BreakdownReportKey.entryPages]: {
    dimensions: ['visit:entry_page'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv)
        return [
          VISITORS_AS_UNIQUE_ENTRANCES,
          VISITS_AS_TOTAL_ENTRANCES,
          BOUNCE_RATE,
          VISIT_DURATION
        ]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [
          VISITORS_AS_UNIQUE_ENTRANCES,
          PERCENTAGE,
          VISITS_AS_TOTAL_ENTRANCES,
          BOUNCE_RATE,
          VISIT_DURATION
        ]
      return [VISITORS_AS_UNIQUE_ENTRANCES, PERCENTAGE]
    },
    detailsTitle: 'Entry pages',
    detailsPath: 'entry-pages',
    dimensionLabel: 'Entry page',
    alwaysOnFilters: [['is_not', 'visit:entry_page', ['']]]
  },
  [BreakdownReportKey.exitPages]: {
    dimensions: ['visit:exit_page'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv)
        return [
          VISITORS_AS_UNIQUE_EXITS,
          VISITS_AS_TOTAL_EXITS,
          ...(ctx.hasEventFilters ? [] : [EXIT_RATE])
        ]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [
          VISITORS_AS_UNIQUE_EXITS,
          PERCENTAGE,
          VISITS_AS_TOTAL_EXITS,
          ...(ctx.hasEventFilters ? [] : [EXIT_RATE])
        ]
      return [VISITORS_AS_UNIQUE_EXITS, PERCENTAGE]
    },
    detailsTitle: 'Exit pages',
    detailsPath: 'exit-pages',
    dimensionLabel: 'Exit page',
    alwaysOnFilters: [['is_not', 'visit:exit_page', ['']]]
  },
  [BreakdownReportKey.browsers]: {
    dimensions: ['visit:browser'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Browsers',
    detailsPath: 'browsers',
    dimensionLabel: 'Browser'
  },
  [BreakdownReportKey.browserVersions]: {
    dimensions: ['visit:browser_version', 'visit:browser'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Browser versions',
    detailsPath: 'browser-versions',
    dimensionLabel: 'Browser version'
  },
  [BreakdownReportKey.operatingSystems]: {
    dimensions: ['visit:os'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Operating systems',
    detailsPath: 'operating-systems',
    dimensionLabel: 'Operating system'
  },
  [BreakdownReportKey.operatingSystemVersions]: {
    dimensions: ['visit:os_version', 'visit:os'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Operating system versions',
    detailsPath: 'operating-system-versions',
    dimensionLabel: 'Operating system version'
  },
  [BreakdownReportKey.screenSizes]: {
    dimensions: ['visit:device'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Devices',
    detailsPath: 'screen-sizes',
    dimensionLabel: 'Device'
  },
  [BreakdownReportKey.channels]: {
    dimensions: ['visit:channel'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Top acquisition channels',
    detailsPath: 'channels',
    dimensionLabel: 'Channel'
  },
  [BreakdownReportKey.sources]: {
    dimensions: ['visit:source'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Top sources',
    detailsPath: 'sources',
    dimensionLabel: 'Source'
  },
  [BreakdownReportKey.referrers]: {
    dimensions: ['visit:referrer'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Referrer drilldown',
    detailsPath: 'referrers/:referrer',
    dimensionLabel: 'Referrer'
  },
  [BreakdownReportKey.utmMediums]: {
    dimensions: ['visit:utm_medium'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'UTM mediums',
    detailsPath: 'utm_mediums',
    dimensionLabel: 'UTM medium',
    alwaysOnFilters: [['is_not', 'visit:utm_medium', ['']]]
  },
  [BreakdownReportKey.utmSources]: {
    dimensions: ['visit:utm_source'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'UTM sources',
    detailsPath: 'utm_sources',
    dimensionLabel: 'UTM source',
    alwaysOnFilters: [['is_not', 'visit:utm_source', ['']]]
  },
  [BreakdownReportKey.utmCampaigns]: {
    dimensions: ['visit:utm_campaign'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'UTM campaigns',
    detailsPath: 'utm_campaigns',
    dimensionLabel: 'UTM campaign',
    alwaysOnFilters: [['is_not', 'visit:utm_campaign', ['']]]
  },
  [BreakdownReportKey.utmContents]: {
    dimensions: ['visit:utm_content'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'UTM contents',
    detailsPath: 'utm_contents',
    dimensionLabel: 'UTM content',
    alwaysOnFilters: [['is_not', 'visit:utm_content', ['']]]
  },
  [BreakdownReportKey.utmTerms]: {
    dimensions: ['visit:utm_term'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS, BOUNCE_RATE, VISIT_DURATION]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      if (ctx.isDetailed)
        return [VISITORS, PERCENTAGE, BOUNCE_RATE, VISIT_DURATION]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'UTM terms',
    detailsPath: 'utm_terms',
    dimensionLabel: 'UTM term',
    alwaysOnFilters: [['is_not', 'visit:utm_term', ['']]]
  },
  [BreakdownReportKey.countries]: {
    dimensions: ['visit:country_name', 'visit:country'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Top countries',
    detailsPath: 'countries',
    dimensionLabel: 'Country',
    alwaysOnFilters: [['is_not', 'visit:country', ['\0\0', 'ZZ']]]
  },
  [BreakdownReportKey.regions]: {
    // the 3rd dimension "visit:country" is needed to render the country flag
    dimensions: ['visit:region_name', 'visit:region', 'visit:country'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Top regions',
    detailsPath: 'regions',
    dimensionLabel: 'Region',
    alwaysOnFilters: [['is_not', 'visit:region', ['']]]
  },
  [BreakdownReportKey.cities]: {
    // the 3rd dimension "visit:country" is needed to render the country flag
    dimensions: ['visit:city_name', 'visit:city', 'visit:country'],
    getMetrics: (ctx) => {
      if (ctx.isCsv && ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isCsv) return [VISITORS]
      if (ctx.hasConversionGoalFilter && ctx.isDetailed)
        return [
          TOTAL_VISITORS,
          VISITORS_AS_CONVERSIONS,
          GROUP_CONVERSION_RATE,
          ...(ctx.isRevenueAvailable ? [TOTAL_REVENUE, AVERAGE_REVENUE] : [])
        ]
      if (ctx.hasConversionGoalFilter)
        return [VISITORS_AS_CONVERSIONS, GROUP_CONVERSION_RATE]
      if (ctx.isRealtime) return [VISITORS_AS_CURRENT_VISITORS, PERCENTAGE]
      return [VISITORS, PERCENTAGE]
    },
    detailsTitle: 'Top cities',
    detailsPath: 'cities',
    dimensionLabel: 'City',
    alwaysOnFilters: [['is_not', 'visit:city', [0]]]
  }
}
