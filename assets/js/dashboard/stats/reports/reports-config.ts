import { ApiFilter, NonTimeDimension } from '../../stats-query'
import { Metric } from '../metrics'

export type MetricContext = {
  hasConversionGoalFilter?: boolean
  isRealtime?: boolean
  isCsv?: boolean
  isDetailed?: boolean
  isRevenueAvailable?: boolean
  hasEventFilters?: boolean
}

export type MetricsByContext = {
  realtimeMetrics: Metric[]
  defaultIndexMetrics: Metric[]
  defaultDetailedMetrics: Metric[]
  defaultCsvMetrics: Metric[]
  goalFilterIndexMetrics: Metric[]
  goalFilterDetailedMetrics: Metric[]
  goalFilterCsvMetrics: Metric[]
}

export type BreakdownReportConfig = {
  dimensions: [NonTimeDimension, ...NonTimeDimension[]]
  getMetrics: (context: MetricContext) => Metric[]
  detailsTitle: string
  detailsPath: string
  dimensionLabel: string
  alwaysOnFilters?: ApiFilter[]
  searchDimension?: NonTimeDimension
}

export const COMMON_BREAKDOWN_METRICS_BY_CONTEXT: MetricsByContext = {
  realtimeMetrics: ['visitors', 'percentage'],
  defaultIndexMetrics: ['visitors', 'percentage'],
  defaultDetailedMetrics: [
    'visitors',
    'percentage',
    'bounce_rate',
    'visit_duration'
  ],
  defaultCsvMetrics: ['visitors', 'bounce_rate', 'visit_duration'],
  goalFilterIndexMetrics: ['visitors', 'group_conversion_rate'],
  goalFilterDetailedMetrics: [
    'total_visitors',
    'visitors',
    'group_conversion_rate'
  ],
  goalFilterCsvMetrics: ['visitors', 'group_conversion_rate']
}

function chooseMetrics(mbc: MetricsByContext, ctx: MetricContext): Metric[] {
  const {
    isRealtime,
    isCsv,
    isDetailed,
    hasConversionGoalFilter,
    isRevenueAvailable
  } = ctx
  if (isCsv && hasConversionGoalFilter) {
    return mbc.goalFilterCsvMetrics
  }
  if (isCsv) {
    return mbc.defaultCsvMetrics
  }
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
  'pagesWithHostname' = 'pagesWithHostname',
  'entryPages' = 'entryPages',
  'entryPagesWithHostname' = 'entryPagesWithHostname',
  'exitPages' = 'exitPages',
  'exitPagesWithHostname' = 'exitPagesWithHostname',
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
  'cities' = 'cities',
  'goals' = 'goals'
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
      ],
      defaultCsvMetrics: [
        'visitors',
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
  [BreakdownReportKey.pagesWithHostname]: {
    dimensions: ['event:hostname', 'event:page'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: [
        'visitors',
        'percentage',
        'pageviews',
        'bounce_rate',
        'time_on_page',
        'scroll_depth'
      ],
      defaultCsvMetrics: [
        'visitors',
        'pageviews',
        'bounce_rate',
        'time_on_page',
        'scroll_depth'
      ]
    }),
    detailsTitle: 'Top pages',
    detailsPath: 'pages-with-hostname',
    dimensionLabel: 'URL',
    searchDimension: 'event:page'
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
      ],
      defaultCsvMetrics: ['visitors', 'visits', 'bounce_rate', 'visit_duration']
    }),
    detailsTitle: 'Entry pages',
    detailsPath: 'entry-pages',
    dimensionLabel: 'Entry page',
    alwaysOnFilters: [['is_not', 'visit:entry_page', ['']]]
  },
  [BreakdownReportKey.entryPagesWithHostname]: {
    dimensions: ['visit:entry_page_hostname', 'visit:entry_page'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: [
        'visitors',
        'percentage',
        'visits',
        'bounce_rate',
        'visit_duration'
      ],
      defaultCsvMetrics: ['visitors', 'visits', 'bounce_rate', 'visit_duration']
    }),
    detailsTitle: 'Entry pages',
    detailsPath: 'entry-pages-with-hostname',
    dimensionLabel: 'URL',
    alwaysOnFilters: [['is_not', 'visit:entry_page', ['']]],
    searchDimension: 'visit:entry_page'
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
          ],
          defaultCsvMetrics: ['visitors', 'visits', 'exit_rate']
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
  [BreakdownReportKey.exitPagesWithHostname]: {
    dimensions: ['visit:exit_page_hostname', 'visit:exit_page'],
    getMetrics: (ctx) => {
      const base = chooseMetrics(
        {
          ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
          defaultDetailedMetrics: [
            'visitors',
            'percentage',
            'visits',
            'exit_rate'
          ],
          defaultCsvMetrics: ['visitors', 'visits', 'exit_rate']
        },
        ctx
      )

      return ctx.hasEventFilters ? base.filter((m) => m !== 'exit_rate') : base
    },
    detailsTitle: 'Exit pages',
    detailsPath: 'exit-pages-with-hostname',
    dimensionLabel: 'URL',
    alwaysOnFilters: [['is_not', 'visit:exit_page', ['']]],
    searchDimension: 'visit:exit_page'
  },
  [BreakdownReportKey.browsers]: {
    dimensions: ['visit:browser'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultCsvMetrics: ['visitors']
    }),
    detailsTitle: 'Browsers',
    detailsPath: 'browsers',
    dimensionLabel: 'Browser'
  },
  [BreakdownReportKey.browserVersions]: {
    dimensions: ['visit:browser_version', 'visit:browser'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultCsvMetrics: ['visitors']
    }),
    detailsTitle: 'Browser versions',
    detailsPath: 'browser-versions',
    dimensionLabel: 'Browser version'
  },
  [BreakdownReportKey.operatingSystems]: {
    dimensions: ['visit:os'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultCsvMetrics: ['visitors']
    }),
    detailsTitle: 'Operating systems',
    detailsPath: 'operating-systems',
    dimensionLabel: 'Operating system'
  },
  [BreakdownReportKey.operatingSystemVersions]: {
    dimensions: ['visit:os_version', 'visit:os'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultCsvMetrics: ['visitors']
    }),
    detailsTitle: 'Operating system versions',
    detailsPath: 'operating-system-versions',
    dimensionLabel: 'Operating system version'
  },
  [BreakdownReportKey.screenSizes]: {
    dimensions: ['visit:device'],
    getMetrics: createGetMetricsFn({
      ...COMMON_BREAKDOWN_METRICS_BY_CONTEXT,
      defaultCsvMetrics: ['visitors']
    }),
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
      defaultDetailedMetrics: ['visitors', 'percentage'],
      defaultCsvMetrics: ['visitors']
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
      defaultDetailedMetrics: ['visitors', 'percentage'],
      defaultCsvMetrics: ['visitors']
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
      defaultDetailedMetrics: ['visitors', 'percentage'],
      defaultCsvMetrics: ['visitors']
    }),
    detailsTitle: 'Top cities',
    detailsPath: 'cities',
    dimensionLabel: 'City',
    alwaysOnFilters: [['is_not', 'visit:city', [0]]]
  },
  [BreakdownReportKey.goals]: {
    dimensions: ['event:goal'],
    getMetrics: (ctx: MetricContext) => {
      if (ctx.isCsv) {
        return ['visitors', 'events']
      }
      if (ctx.isRevenueAvailable) {
        return [
          'visitors',
          'events',
          'conversion_rate',
          'total_revenue',
          'average_revenue'
        ]
      }
      return ['visitors', 'events', 'conversion_rate']
    },
    detailsTitle: 'Goal conversions',
    detailsPath: 'conversions',
    dimensionLabel: 'Goal'
  }
}

export function customPropsReportConfig(
  propKey: string
): BreakdownReportConfig {
  return {
    dimensions: [`event:props:${propKey}` as NonTimeDimension],
    getMetrics: getCustomPropsMetrics,
    detailsTitle: 'Custom property breakdown',
    detailsPath: `custom-prop-values/${propKey}`,
    dimensionLabel: propKey
  }
}

export function getCustomPropsMetrics(ctx: MetricContext): Metric[] {
  if (ctx.hasConversionGoalFilter && ctx.isRevenueAvailable) {
    return [
      'visitors',
      'events',
      'conversion_rate',
      'total_revenue',
      'average_revenue'
    ]
  }
  if (ctx.hasConversionGoalFilter) {
    return ['visitors', 'events', 'conversion_rate']
  }
  return ['visitors', 'events', 'percentage']
}
