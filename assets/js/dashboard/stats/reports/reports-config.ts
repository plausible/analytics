import { PlausibleSite } from '../../site-context'
import { NonTimeDimension } from '../../stats-query'
import { Metric } from '../metrics'
import * as url from '../../util/url'
import { QueryResultRow } from '../../api'

export type MetricsByContext = {
  realtimeMetrics: Metric[]
  defaultIndexMetrics: Metric[]
  defaultDetailedMetrics: Metric[]
  goalFilterIndexMetrics: Metric[]
  goalFilterDetailedMetrics: Metric[]
}

type BreakdownReportConfig = {
  dimensions: [NonTimeDimension] | [NonTimeDimension, NonTimeDimension]
  metricsByContext: MetricsByContext
  detailsTitle: string
  detailsPath: string
  dimensionLabel: string
  getExternalLinkUrl?: (
    site: PlausibleSite,
    row: QueryResultRow
  ) => string | null
}

const COMMON_METRICS_BY_CONTEXT: MetricsByContext = {
  realtimeMetrics: ['visitors', 'percentage'],
  defaultIndexMetrics: ['visitors', 'percentage'],
  defaultDetailedMetrics: [
    'visitors',
    'percentage',
    'visits',
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

function getExternalLinkUrlForPage(
  site: PlausibleSite,
  row: QueryResultRow
): string | null {
  return url.externalLinkForPage(site, row.dimensions[0])
}

export enum BreakdownReportKey {
  'pages' = 'pages',
  'entryPages' = 'entryPages',
  'exitPages' = 'exitPages'
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
    dimensionLabel: 'Page',
    getExternalLinkUrl: getExternalLinkUrlForPage
  },
  [BreakdownReportKey.entryPages]: {
    dimensions: ['visit:entry_page'],
    metricsByContext: COMMON_METRICS_BY_CONTEXT,
    detailsTitle: 'Entry pages',
    detailsPath: 'entry-pages',
    dimensionLabel: 'Entry page',
    getExternalLinkUrl: getExternalLinkUrlForPage
  },
  [BreakdownReportKey.exitPages]: {
    dimensions: ['visit:exit_page'],
    metricsByContext: {
      ...COMMON_METRICS_BY_CONTEXT,
      defaultDetailedMetrics: ['visitors', 'percentage', 'visits', 'exit_rate']
    },
    detailsTitle: 'Exit pages',
    detailsPath: 'exit-pages',
    dimensionLabel: 'Exit page',
    getExternalLinkUrl: getExternalLinkUrlForPage
  }
}
