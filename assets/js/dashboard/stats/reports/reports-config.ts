import { ApiFilter, NonTimeDimension } from '../../stats-query'
import { Metric } from '../metrics'

export type MetricContext = {
  hasConversionGoalFilter: boolean
  isRealtime?: boolean
  isDetailed?: boolean
  isRevenueAvailable?: boolean
  hasEventFilters?: boolean
}

export type MetricsByContext = {
  realtimeMetrics: Metric[]
  defaultIndexMetrics: Metric[]
  defaultDetailedMetrics: Metric[]
  goalFilterIndexMetrics: Metric[]
  goalFilterDetailedMetrics: Metric[]
}

export type BreakdownReportConfig = {
  dimensions: [NonTimeDimension, ...NonTimeDimension[]]
  getMetrics: (context: MetricContext) => Metric[]
  detailsTitle: string
  detailsPath: string
  dimensionLabel: string
  alwaysOnFilters?: ApiFilter[]
}

const COMMON_BREAKDOWN_METRICS_BY_CONTEXT: MetricsByContext = {
  realtimeMetrics: ['visitors', 'percentage'],
  defaultIndexMetrics: ['visitors', 'percentage'],
  defaultDetailedMetrics: [
    'visitors',
    'percentage',
    'bounce_rate',
    'visit_duration'
  ],
  goalFilterIndexMetrics: ['visitors', 'group_conversion_rate'],
  goalFilterDetailedMetrics: [
    'total_visitors',
    'visitors',
    'group_conversion_rate'
  ]
}

function chooseMetrics(mbc: MetricsByContext, ctx: MetricContext): Metric[] {
  const {
    isRealtime,
    isDetailed,
    hasConversionGoalFilter,
    isRevenueAvailable
  } = ctx
  if (hasConversionGoalFilter && isDetailed && isRevenueAvailable) {
    return [
      ...mbc.goalFilterDetailedMetrics,
      'total_revenue',
      'average_revenue'
    ]
  }
  if (hasConversionGoalFilter && isDetailed) {
    return mbc.goalFilterDetailedMetrics
  }
  if (hasConversionGoalFilter) {
    return mbc.goalFilterIndexMetrics
  }
  if (isRealtime) {
    return mbc.realtimeMetrics
  }
  if (isDetailed) {
    return mbc.defaultDetailedMetrics
  }
  return mbc.defaultIndexMetrics
}

function createGetMetricsFn(
  mbc: MetricsByContext
): (context: MetricContext) => Metric[] {
  return (ctx) => chooseMetrics(mbc, ctx)
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
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: [
        'visitors',
        'percentage',
        'pageviews',
        'bounce_rate',
        'time_on_page',
        'scroll_depth'
      ]
    }),
    detailsTitle: 'Top pages',
    detailsPath: 'pages',
    dimensionLabel: 'Page'
  },
  [BreakdownReportKey.entryPages]: {
    dimensions: ['visit:entry_page'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: [
        'visitors',
        'percentage',
        'visits',
        'bounce_rate',
        'visit_duration'
      ]
    }),
    detailsTitle: 'Entry pages',
    detailsPath: 'entry-pages',
    dimensionLabel: 'Entry page',
    alwaysOnFilters: [['is_not', 'visit:entry_page', ['']]]
  },
  [BreakdownReportKey.exitPages]: {
    dimensions: ['visit:exit_page'],
    getMetrics: (ctx) => {
      const base = chooseMetrics(
        {
          ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
          defaultDetailedMetrics: [
            'visitors',
            'percentage',
            'visits',
            'exit_rate'
          ]
        },
        ctx
      )

      return ctx.hasEventFilters ? base.filter((m) => m !== 'exit_rate') : base
    },
    detailsTitle: 'Exit pages',
    detailsPath: 'exit-pages',
    dimensionLabel: 'Exit page',
    alwaysOnFilters: [['is_not', 'visit:exit_page', ['']]]
  },
  [BreakdownReportKey.browsers]: {
    dimensions: ['visit:browser'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Browsers',
    detailsPath: 'browsers',
    dimensionLabel: 'Browser'
  },
  [BreakdownReportKey.browserVersions]: {
    dimensions: ['visit:browser_version', 'visit:browser'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Browser versions',
    detailsPath: 'browser-versions',
    dimensionLabel: 'Browser version'
  },
  [BreakdownReportKey.operatingSystems]: {
    dimensions: ['visit:os'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Operating systems',
    detailsPath: 'operating-systems',
    dimensionLabel: 'Operating system'
  },
  [BreakdownReportKey.operatingSystemVersions]: {
    dimensions: ['visit:os_version', 'visit:os'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Operating system versions',
    detailsPath: 'operating-system-versions',
    dimensionLabel: 'Operating system version'
  },
  [BreakdownReportKey.screenSizes]: {
    dimensions: ['visit:device'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Devices',
    detailsPath: 'screen-sizes',
    dimensionLabel: 'Device'
  },
  [BreakdownReportKey.channels]: {
    dimensions: ['visit:channel'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Top acquisition channels',
    detailsPath: 'channels',
    dimensionLabel: 'Channel'
  },
  [BreakdownReportKey.sources]: {
    dimensions: ['visit:source'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Top sources',
    detailsPath: 'sources',
    dimensionLabel: 'Source'
  },
  [BreakdownReportKey.referrers]: {
    dimensions: ['visit:referrer'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'Referrer drilldown',
    detailsPath: 'referrers/:referrer',
    dimensionLabel: 'Referrer'
  },
  [BreakdownReportKey.utmMediums]: {
    dimensions: ['visit:utm_medium'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'UTM mediums',
    detailsPath: 'utm_mediums',
    dimensionLabel: 'UTM medium',
    alwaysOnFilters: [['is_not', 'visit:utm_medium', ['']]]
  },
  [BreakdownReportKey.utmSources]: {
    dimensions: ['visit:utm_source'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'UTM sources',
    detailsPath: 'utm_sources',
    dimensionLabel: 'UTM source',
    alwaysOnFilters: [['is_not', 'visit:utm_source', ['']]]
  },
  [BreakdownReportKey.utmCampaigns]: {
    dimensions: ['visit:utm_campaign'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'UTM campaigns',
    detailsPath: 'utm_campaigns',
    dimensionLabel: 'UTM campaign',
    alwaysOnFilters: [['is_not', 'visit:utm_campaign', ['']]]
  },
  [BreakdownReportKey.utmContents]: {
    dimensions: ['visit:utm_content'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'UTM contents',
    detailsPath: 'utm_contents',
    dimensionLabel: 'UTM content',
    alwaysOnFilters: [['is_not', 'visit:utm_content', ['']]]
  },
  [BreakdownReportKey.utmTerms]: {
    dimensions: ['visit:utm_term'],
    getMetrics: createGetMetricsFn(COMMON_BREAKDOWN_METRICS_BY_CONTEXT),
    detailsTitle: 'UTM terms',
    detailsPath: 'utm_terms',
    dimensionLabel: 'UTM term',
    alwaysOnFilters: [['is_not', 'visit:utm_term', ['']]]
  },
  [BreakdownReportKey.countries]: {
    dimensions: ['visit:country_name', 'visit:country'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: ['visitors', 'percentage']
    }),
    detailsTitle: 'Top countries',
    detailsPath: 'countries',
    dimensionLabel: 'Country',
    alwaysOnFilters: [['is_not', 'visit:country', ['\0\0', 'ZZ']]]
  },
  [BreakdownReportKey.regions]: {
    // the 3rd dimension "visit:country" is needed to render the country flag
    dimensions: ['visit:region_name', 'visit:region', 'visit:country'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: ['visitors', 'percentage']
    }),
    detailsTitle: 'Top regions',
    detailsPath: 'regions',
    dimensionLabel: 'Region',
    alwaysOnFilters: [['is_not', 'visit:region', ['']]]
  },
  [BreakdownReportKey.cities]: {
    // the 3rd dimension "visit:country" is needed to render the country flag
    dimensions: ['visit:city_name', 'visit:city', 'visit:country'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: ['visitors', 'percentage']
    }),
    detailsTitle: 'Top cities',
    detailsPath: 'cities',
    dimensionLabel: 'City',
    alwaysOnFilters: [['is_not', 'visit:city', [0]]]
  }
}
