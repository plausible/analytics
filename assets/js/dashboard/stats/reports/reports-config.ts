import { NonTimeDimension } from '../../stats-query'
import { Metric } from '../metrics'

export type MetricsByContext = {
  realtimeMetrics: Metric[]
  defaultIndexMetrics: Metric[]
  defaultDetailedMetrics: Metric[]
  goalFilterIndexMetrics: Metric[]
  goalFilterDetailedMetrics: Metric[]
}

export type BreakdownReportConfig = {
  dimensions: [NonTimeDimension] | [NonTimeDimension, NonTimeDimension]
  metricsByContext: MetricsByContext
  detailsTitle: string
  detailsPath: string
  dimensionLabel: string
}

const COMMON_METRICS_BY_CONTEXT: MetricsByContext = {
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
  'utmTerms' = 'utmTerms'
}

export const BREAKDOWN_REPORTS: Record<
  BreakdownReportKey,
  BreakdownReportConfig
> = {
  [BreakdownReportKey.pages]: {
    dimensions: ['event:page'],
    metricsByContext: {
      ...COMMON_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: [
        'visitors',
        'percentage',
        'pageviews',
        'bounce_rate',
        'time_on_page',
        'scroll_depth'
      ]
    },
    detailsTitle: 'Top pages',
    detailsPath: 'pages',
    dimensionLabel: 'Page'
  },
  [BreakdownReportKey.entryPages]: {
    dimensions: ['visit:entry_page'],
    metricsByContext: {
      ...COMMON_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: [
        'visitors',
        'percentage',
        'visits',
        'bounce_rate',
        'visit_duration'
      ]
    },
    detailsTitle: 'Entry pages',
    detailsPath: 'entry-pages',
    dimensionLabel: 'Entry page'
  },
  [BreakdownReportKey.exitPages]: {
    dimensions: ['visit:exit_page'],
    metricsByContext: {
      ...COMMON_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: ['visitors', 'percentage', 'visits', 'exit_rate']
    },
    detailsTitle: 'Exit pages',
    detailsPath: 'exit-pages',
    dimensionLabel: 'Exit page'
  },
  [BreakdownReportKey.browsers]: {
    dimensions: ['visit:browser'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Browsers',
    detailsPath: 'browsers',
    dimensionLabel: 'Browser'
  },
  [BreakdownReportKey.browserVersions]: {
    dimensions: ['visit:browser_version', 'visit:browser'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Browser versions',
    detailsPath: 'browser-versions',
    dimensionLabel: 'Browser version'
  },
  [BreakdownReportKey.operatingSystems]: {
    dimensions: ['visit:os'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Operating systems',
    detailsPath: 'operating-systems',
    dimensionLabel: 'Operating system'
  },
  [BreakdownReportKey.operatingSystemVersions]: {
    dimensions: ['visit:os_version', 'visit:os'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Operating system versions',
    detailsPath: 'operating-system-versions',
    dimensionLabel: 'Operating system version'
  },
  [BreakdownReportKey.screenSizes]: {
    dimensions: ['visit:device'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Devices',
    detailsPath: 'screen-sizes',
    dimensionLabel: 'Device'
  },
  [BreakdownReportKey.channels]: {
    dimensions: ['visit:channel'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Top acquisition channels',
    detailsPath: 'channels',
    dimensionLabel: 'Channel'
  },
  [BreakdownReportKey.sources]: {
    dimensions: ['visit:source'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Top source',
    detailsPath: 'sources',
    dimensionLabel: 'Source'
  },
  [BreakdownReportKey.referrers]: {
    dimensions: ['visit:referrer'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Referrer drilldown',
    detailsPath: 'referrers/:referrer',
    dimensionLabel: 'Referrer'
  },
  [BreakdownReportKey.utmMediums]: {
    dimensions: ['visit:utm_medium'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'UTM Mediums',
    detailsPath: 'utm_mediums',
    dimensionLabel: 'Medium'
  },
  [BreakdownReportKey.utmSources]: {
    dimensions: ['visit:utm_source'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'UTM Sources',
    detailsPath: 'utm_sources',
    dimensionLabel: 'Source'
  },
  [BreakdownReportKey.utmCampaigns]: {
    dimensions: ['visit:utm_campaign'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'UTM Campaigns',
    detailsPath: 'utm_campaigns',
    dimensionLabel: 'Campaign'
  },
  [BreakdownReportKey.utmContents]: {
    dimensions: ['visit:utm_content'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'UTM Contents',
    detailsPath: 'utm_contents',
    dimensionLabel: 'Content'
  },
  [BreakdownReportKey.utmTerms]: {
    dimensions: ['visit:utm_term'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'UTM Terms',
    detailsPath: 'utm_terms',
    dimensionLabel: 'Term'
  }
}
