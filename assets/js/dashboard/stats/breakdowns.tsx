import React, { ReactNode, useEffect, useMemo, useRef } from 'react'
import { SortDirection } from '../../types/query-api'
import type { QueryResultRow, QueryResultQuery } from '../api'
import { Metric } from './metrics'
import { FilterInfo } from '../components/drilldown-link'
import { ChangeArrow } from './reports/change-arrow'
import { MetricFormatterLong, ValueType } from './reports/metric-formatter'
import dayjs from 'dayjs'
import {
  addFilter,
  ApiFilter,
  NonTimeDimension,
  OrderByEntry,
  StatsQuery
} from '../stats-query'
import { Filter } from '../dashboard-state'
import classNames from 'classnames'
import { DIRECT_NONE } from './sources'
import { StatsReportQueryKey } from '../hooks/use-query-api'

export type SharedBreakdownReportProps = {
  dimensionLabel: string
  dimensions: NonTimeDimension[]
  metrics: Metric[]
  alwaysOnFilters?: ApiFilter[]
  getStatsQuery?: (queryKey: StatsReportQueryKey) => StatsQuery
  /**
   * When true, `percentage` is shown inline inside the Visitors
   * cell rather than as its own column. Set to false for reports that want
   * percentage as a separate breakdown column (e.g. custom properties).
   */
  bundlePercentageWithVisitors?: boolean
  /**
   * Metrics that should be dropped from the rendered columns when every row
   * (across all loaded pages) has null for that metric. Used by goal breakdowns
   * to hide revenue columns when the current rows have no revenue data.
   */
  hideMetricsIfAllNull?: Metric[]
}

export type ColumnConfiguration<T> = {
  /** Unique column ID, used for sorting purposes and as a React key */
  key: string
  /** Column title */
  renderLabel: () => ReactNode
  /** Renders any cell in this column — name cells, metric cells, etc. */
  renderCell: (item: T, isActive?: boolean) => ReactNode
  /** If defined, the column is considered sortable. @see SortButton */
  onSort?: () => void
  sortDirection?: SortDirection
  /** CSS class string. @example "w-24 md:w-32" */
  width?: string
  /** Aligns column content. */
  align?: 'left' | 'right'
  /** Hides the column on mobile (below md breakpoint). */
  hideOnMobile?: boolean
}

export type GetFilterInfo = (
  dimension: NonTimeDimension,
  row: QueryResultRow
) => FilterInfo | null

export function defaultGetFilterInfo(
  dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo {
  const dimensionWithoutPrefix = dimension.replace(/^(event|visit):/, '')

  return {
    prefix: dimensionWithoutPrefix,
    filter: ['is', dimensionWithoutPrefix, [row.dimensions[0]]] as Filter
  }
}

export function getReferrerUrlFilterInfo(
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo | null {
  if (row.dimensions[0] === DIRECT_NONE) {
    return null
  }
  return {
    prefix: 'referrer',
    filter: ['is', 'referrer', [row.dimensions[0]]]
  }
}

export const getScreenFilterInfo = (
  _dimension: NonTimeDimension,
  row: QueryResultRow
): FilterInfo => ({
  filter: ['is', 'screen', [row.dimensions[0]]],
  prefix: 'screen'
})

export function MetricValueWrapper({
  className,
  children
}: {
  className?: string
  children: ReactNode
}) {
  return (
    <span
      className={classNames(
        'font-medium text-sm block text-gray-800 dark:text-gray-200',
        className
      )}
      data-testid="metric-value"
    >
      {children}
    </span>
  )
}

export function MetricValueTooltipContent({
  value,
  comparison,
  metric,
  metricLabel,
  dateRangeLabel,
  comparisonDateRangeLabel
}: {
  value: ValueType
  comparison: { value: ValueType; change: number } | null
  metric: Metric
  metricLabel: string
  dateRangeLabel: string
  comparisonDateRangeLabel: string | null
}) {
  const longFormatter = MetricFormatterLong[metric]
  const label = metricLabel.length >= 3 ? ` ${metricLabel.toLowerCase()}` : ''

  if (comparison && comparisonDateRangeLabel) {
    return (
      <div className="text-left whitespace-nowrap py-1 space-y-2">
        <div>
          <div className="flex gap-x-4">
            <div className="flex flex-col">
              <span className="font-medium text-sm/6 text-white">
                {longFormatter(value)}
                {label}
              </span>
              <div className="font-normal text-xs text-white">
                {dateRangeLabel}
              </div>
            </div>
            <ChangeArrow
              metric={metric}
              change={comparison.change}
              className="text-xs/6 font-medium text-white"
            />
          </div>
        </div>
        <div className="w-full border-t border-gray-600" />
        <div>
          <div className="font-medium text-sm/6 text-gray-300/80">
            {longFormatter(comparison.value)}
            {label}
          </div>
          <div className="font-normal text-xs text-gray-300/80">
            {comparisonDateRangeLabel}
          </div>
        </div>
      </div>
    )
  }

  return <div className="whitespace-nowrap">{longFormatter(value)}</div>
}

export function formatDateRangeLabel([from, to]: [string, string]): string {
  const fromDay = dayjs(from.slice(0, 19))
  const toDay = dayjs(to.slice(0, 19))
  if (fromDay.isSame(toDay, 'day')) return fromDay.format('D MMM YYYY')
  if (fromDay.isSame(toDay, 'year'))
    return `${fromDay.format('D MMM')} - ${toDay.format('D MMM YYYY')}`
  return `${fromDay.format('D MMM YY')} - ${toDay.format('D MMM YY')}`
}

export function useBodyPortalRef() {
  const portalRef = useRef<HTMLElement | null>(null)
  useEffect(() => {
    if (typeof document !== 'undefined') {
      portalRef.current = document.body
    }
  }, [])
  return portalRef
}

export function ExternalLinkIcon() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      className="inline size-3.5 mb-0.5 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
    >
      <path
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2"
        d="M9 5H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4M12 12l9-9-.303.303M14 3h7v7"
      />
    </svg>
  )
}

export function extractMetricValue(
  row: QueryResultRow,
  query: QueryResultQuery,
  metricKey: string
): {
  metricIndex: number
  value: ValueType
  comparison: { value: ValueType; change: number } | null
} {
  const metricIndex = query.metrics.indexOf(metricKey as Metric)
  const value: ValueType =
    metricIndex >= 0 ? (row.metrics[metricIndex] ?? null) : null
  const comparison =
    row.comparison && query.comparison_date_range
      ? {
          value: row.comparison.metrics[metricIndex] ?? null,
          change: row.comparison.change[metricIndex]
        }
      : null
  return { metricIndex, value, comparison }
}

const CANNOT_ORDER_BY_DIMENSIONS = ['event:goal']

export function dimensionOrderBy(dimensions: NonTimeDimension[]) {
  return dimensions
    .filter((dim) => !CANNOT_ORDER_BY_DIMENSIONS.includes(dim))
    .map((dim): OrderByEntry => [dim, 'asc'])
}

export function addDimensionSearchFilter(
  statsQuery: StatsQuery,
  dimension: string,
  search: string
) {
  return addFilter(statsQuery, [
    'contains',
    dimension,
    [search],
    { case_sensitive: false }
  ] as ApiFilter)
}

export function useColumnsHiddenForAllNull(
  rows: QueryResultRow[] | null | undefined,
  query: QueryResultQuery | null | undefined,
  hideMetricsIfAllNull: Metric[] | undefined
): Set<Metric> {
  return useMemo(() => {
    const hidden = new Set<Metric>()
    if (!hideMetricsIfAllNull || !rows?.length || !query) return hidden
    for (const metric of hideMetricsIfAllNull) {
      const idx = query.metrics.indexOf(metric)
      if (idx === -1) continue
      if (rows.every((row) => row.metrics[idx] == null)) hidden.add(metric)
    }
    return hidden
  }, [rows, query, hideMetricsIfAllNull])
}
