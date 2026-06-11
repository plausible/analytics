import React, { ReactNode, useEffect, useMemo, useState } from 'react'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  StatsReportId,
  StatsReportQueryKey,
  useSearchAndPaginateQueryAPI
} from '../../hooks/use-query-api'
import {
  getStoredOrderBy,
  MetricOrderBy,
  useMetricOrderBy,
  useRememberOrderBy
} from '../../hooks/use-metric-order-by'
import { SortDirection } from '../../../types/query-api'
import { Metric } from '../metrics'
import { BreakdownTable } from './breakdown-table'
import { ApiFilter, NonTimeDimension, OrderByEntry } from '../../stats-query'
import { useSiteContext } from '../../site-context'
import { DrilldownLink } from '../../components/drilldown-link'
import {
  ColumnConfiguration,
  MetricValueTooltipContent,
  formatDateRangeLabel,
  useBodyPortalRef,
  extractMetricValue,
  GetFilterInfo,
  BreakdownMetric,
  MetricElement,
  MetricElementProps
} from '../breakdowns'
import {
  QueryResultRow,
  QueryResultMeta,
  QueryResultQuery,
  QueryApiResponse
} from '../../api'
import classNames from 'classnames'
import { Tooltip } from '../../util/tooltip'
import { ChangeArrow } from '../reports/change-arrow'
import {
  MetricFormatterShort,
  MetricFormatterLong
} from '../reports/metric-formatter'
import { SortButton } from '../../components/sort-button'
import { rootRoute } from '../../router'
import { isSortable } from '../metric-utils'

type PaginatedData = { pages: QueryApiResponse[] }

type DetailsBreakdownProps = {
  title: ReactNode
  dimensions: NonTimeDimension[]
  dimensionLabel: string
  metrics: BreakdownMetric[]
  alwaysOnFilters?: ApiFilter[]
  defaultOrderBy?: MetricOrderBy
  searchEnabled?: boolean
  onDataReady?: (data: PaginatedData) => void
  DimensionElement: (props: DimensionCellProps) => ReactNode
  DefaultMetricElement?: MetricElement
}

const VISITORS_WITH_PERCENTAGE_COLUMN_WIDTH = 'w-36'

const getMetricCellWidthClass = (
  metric: Metric,
  metricLabel: string
): string => {
  if (['average_revenue', 'total_revenue'].includes(metric)) {
    return 'w-32 min-w-32'
  }

  if (metricLabel.length < 3) {
    return 'w-28 min-w-28 md:w-24 md:min-w-24'
  }

  if (metricLabel.length < 15) {
    return 'w-28 min-w-28'
  }

  return 'w-32 min-w-32'
}

/**
 * Convenience: takes a list of `BreakdownMetric`s and applies the
 * standard "bundle visitors+percentage" overlay for the details modal —
 * the visitors spec is given the modal's `VisitorsWithPercentageCell` plus
 * the wider column width; the percentage spec is requested but hidden
 * from the column list. Specs that aren't visitors or percentage are
 * passed through unchanged. If either of the two is absent, the input is
 * returned as-is.
 */
export function bundleVisitorsWithPercentage(
  specs: BreakdownMetric[]
): BreakdownMetric[] {
  const hasBoth =
    specs.some((s) => s.key === 'visitors') &&
    specs.some((s) => s.key === 'percentage')
  if (!hasBoth) return specs
  return specs.map((spec) => {
    if (spec.key === 'visitors') {
      return {
        ...spec,
        Cell: VisitorsWithPercentageCell,
        width: VISITORS_WITH_PERCENTAGE_COLUMN_WIDTH
      }
    }
    if (spec.key === 'percentage') {
      return { ...spec, canShowColumn: () => false }
    }
    return spec
  })
}

export function DetailsBreakdown({
  title,
  dimensionLabel,
  dimensions,
  metrics,
  alwaysOnFilters,
  defaultOrderBy = [] as MetricOrderBy,
  DimensionElement,
  DefaultMetricElement = MetricValueCell,
  searchEnabled = true,
  onDataReady
}: DetailsBreakdownProps) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [search, setSearch] = useState('')

  const requestedMetrics = useMemo(() => metrics.map((m) => m.key), [metrics])
  const metricSpecs = useMemo(
    () => metrics.map(({ key, label }) => ({ key, label })),
    [metrics]
  )

  const storedOrderBy = getStoredOrderBy({
    domain: site.domain,
    dimensionLabel,
    metrics: requestedMetrics,
    fallbackValue: defaultOrderBy
  })

  const { orderBy, orderByDictionary, toggleSortByMetric } = useMetricOrderBy({
    metrics: requestedMetrics,
    defaultOrderBy: storedOrderBy
  })

  useRememberOrderBy({
    effectiveOrderBy: orderBy,
    metrics: requestedMetrics,
    dimensionLabel
  })

  const statsReportQueryKey: StatsReportQueryKey = [
    dimensions.join(',') as StatsReportId,
    {
      dashboardState,
      reportParams: {
        metrics: metricSpecs,
        dimensions,
        order_by: [
          ...(orderBy.length ? orderBy : storedOrderBy),
          ...dimensions.map((dim): OrderByEntry => [dim, 'asc'])
        ],
        alwaysOnFilters
      },
      search
    }
  ]

  const apiState = useSearchAndPaginateQueryAPI(site, statsReportQueryKey)

  useEffect(() => {
    const pages = apiState.data?.pages
    if (pages?.length) {
      onDataReady?.({ pages })
    }
  }, [apiState.data, onDataReady])

  const query: QueryResultQuery | null =
    apiState.data?.pages?.[0]?.query ?? null

  const meta: QueryResultMeta | null =
    (apiState.data?.pages?.[0]?.meta as QueryResultMeta) ?? null

  const columns: ColumnConfiguration<QueryResultRow>[] | null = useMemo(() => {
    if (!query) return null

    const filterDimension = query.dimensions[0] as NonTimeDimension

    // Render each spec in the declared order. Skip those whose
    // `canShowColumn` predicate returns false against the current data —
    // they were requested but hide themselves at render time.
    const data = apiState.data
    const flat: QueryApiResponse | undefined = data?.pages?.[0]
      ? {
          ...data.pages[0],
          // pass merged rows to canShowColumn so revenue-style scans see
          // every loaded page, not just the first.
          results: ([] as QueryResultRow[]).concat(
            ...data.pages.map((p) => p.results)
          )
        }
      : undefined
    const visibleSpecs = flat
      ? metrics.filter((spec) =>
          spec.canShowColumn ? spec.canShowColumn(flat) : true
        )
      : metrics

    return [
      {
        key: 'dimension',
        renderLabel: () => dimensionLabel,
        renderCell: (row, isActive) => (
          <DimensionElement
            row={row}
            filterDimension={filterDimension}
            isActive={isActive}
          />
        ),
        width: 'w-48 max-w-48 md:w-56 md:max-w-56',
        align: 'left'
      },
      ...visibleSpecs.map(
        ({ key, label, Cell, width }): ColumnConfiguration<QueryResultRow> => ({
          key,
          renderLabel: () => (
            <MetricLabel
              label={label}
              warning={getMetricWarning(key, meta)}
              sortable={isSortable(key)}
              toggleSort={() => toggleSortByMetric(key)}
              sortDirection={orderByDictionary[key] ?? null}
            />
          ),
          renderCell: (row, isActive) => {
            const Element = Cell ?? DefaultMetricElement
            return (
              <Element
                row={row}
                query={query}
                isActive={isActive}
                metric={key}
                metricLabel={label}
              />
            )
          },
          onSort: isSortable(key) ? () => toggleSortByMetric(key) : undefined,
          sortDirection: orderByDictionary[key],
          width: width ?? getMetricCellWidthClass(key, label),
          align: 'right'
        })
      )
    ]
  }, [
    DimensionElement,
    DefaultMetricElement,
    dimensionLabel,
    query,
    meta,
    orderByDictionary,
    toggleSortByMetric,
    metrics,
    apiState.data
  ])

  const tableData = apiState.data
    ? { pages: apiState.data.pages.map((p) => p.results) }
    : undefined

  return (
    <BreakdownTable<QueryResultRow>
      title={title}
      {...apiState}
      data={tableData}
      columns={columns}
      onSearch={searchEnabled ? setSearch : undefined}
      getRowKey={(row) => row.dimensions[0]}
    />
  )
}

export function VisitorsWithPercentageCell({
  row,
  query,
  isActive
}: MetricElementProps) {
  const portalRef = useBodyPortalRef()

  const { value: visitorsValue, comparison: visitorsComparison } =
    extractMetricValue(row, query, 'visitors')
  const { value: percentageValue } = extractMetricValue(
    row,
    query,
    'percentage'
  )

  const visitorsShortFormatter = MetricFormatterShort['visitors']
  const visitorsLongFormatter = MetricFormatterLong['visitors']
  const percentageFormatter = MetricFormatterShort['percentage']

  const showTooltip = !!visitorsComparison

  const dateRangeLabel = formatDateRangeLabel(query.date_range)
  const comparisonDateRangeLabel = query.comparison_date_range
    ? formatDateRangeLabel(query.comparison_date_range)
    : null

  const percentageCell = (
    <span
      className={classNames('mr-3 text-gray-500 dark:text-gray-400', {
        invisible: !isActive
      })}
    >
      {percentageFormatter(percentageValue)}
    </span>
  )

  const visitorsCell = (
    <span data-testid="metric-value">
      {isActive
        ? visitorsLongFormatter(visitorsValue)
        : visitorsShortFormatter(visitorsValue)}
      {visitorsComparison && (
        <ChangeArrow
          change={visitorsComparison.change}
          metric={'visitors'}
          className="inline-block pl-1 w-4"
          hideNumber
        />
      )}
    </span>
  )

  const visitorsWithTooltip = showTooltip ? (
    <Tooltip
      containerRef={portalRef as React.RefObject<HTMLElement>}
      info={
        <MetricValueTooltipContent
          value={visitorsValue}
          comparison={visitorsComparison}
          metric={'visitors'}
          metricLabel="Visitors"
          dateRangeLabel={dateRangeLabel}
          comparisonDateRangeLabel={comparisonDateRangeLabel}
        />
      }
    >
      {visitorsCell}
    </Tooltip>
  ) : (
    visitorsCell
  )

  return (
    <div className={'flex justify-end'}>
      {percentageCell}
      {visitorsWithTooltip}
    </div>
  )
}

export function MetricValueCell({
  row,
  metric,
  metricLabel,
  query,
  isActive
}: MetricElementProps) {
  const portalRef = useBodyPortalRef()

  const { value, comparison } = extractMetricValue(row, query, metric)

  const shortFormatter = MetricFormatterShort[metric]
  const longFormatter = MetricFormatterLong[metric]

  // Show long format when the row is active (hovered on desktop, tapped on mobile)
  const displayFormatter = isActive ? longFormatter : shortFormatter

  // Tooltip is used for comparison mode only
  const showTooltip = !!comparison

  const valueContent = (
    <span
      className={classNames(
        'font-medium text-sm text-gray-800 dark:text-gray-200',
        showTooltip && 'cursor-default'
      )}
      data-testid="metric-value"
    >
      {displayFormatter(value)}
      {comparison && (
        <ChangeArrow
          change={comparison.change}
          metric={metric}
          className="inline-block pl-1 w-4"
          hideNumber
        />
      )}
    </span>
  )

  if (!showTooltip) return valueContent

  const dateRangeLabel = formatDateRangeLabel(query.date_range)
  const comparisonDateRangeLabel = query.comparison_date_range
    ? formatDateRangeLabel(query.comparison_date_range)
    : null

  return (
    <Tooltip
      containerRef={portalRef as React.RefObject<HTMLElement>}
      info={
        <MetricValueTooltipContent
          value={value}
          comparison={comparison}
          metric={metric}
          metricLabel={metricLabel}
          dateRangeLabel={dateRangeLabel}
          comparisonDateRangeLabel={comparisonDateRangeLabel}
        />
      }
    >
      {valueContent}
    </Tooltip>
  )
}

function getMetricWarning(
  metricKey: Metric,
  meta: QueryResultMeta | null
): string | null {
  const warnings = meta?.metric_warnings
  if (!warnings || !warnings[metricKey]) return null
  const { code, message } = warnings[metricKey]
  if (metricKey === 'bounce_rate' && code === 'no_imported_bounce_rate') {
    return 'Does not include imported data'
  }
  if (metricKey === 'scroll_depth' && code === 'no_imported_scroll_depth') {
    return 'Does not include imported data'
  }
  if (metricKey === 'time_on_page' && code) {
    return message
  }
  return null
}

function MetricLabel({
  label,
  warning,
  sortable,
  toggleSort,
  sortDirection
}: {
  label: string
  warning: string | null
  sortable: boolean
  toggleSort: () => void
  sortDirection: SortDirection | null
}) {
  const labelText = label + (warning ? ' *' : '')
  const inner = sortable ? (
    <SortButton toggleSort={toggleSort} sortDirection={sortDirection}>
      {labelText}
    </SortButton>
  ) : (
    labelText
  )
  if (warning) {
    return (
      <Tooltip
        info={
          <span className="text-xs font-normal whitespace-nowrap">
            {'* ' + warning}
          </span>
        }
        className="inline-block"
      >
        {inner}
      </Tooltip>
    )
  } else {
    return <>{inner}</>
  }
}

export type DimensionCellProps = {
  filterDimension: NonTimeDimension
  row: QueryResultRow
  isActive?: boolean
}

export const DimensionCell = ({
  text,
  icon,
  externalLink,
  filterDimension,
  getFilterInfo,
  row
}: {
  text: string
  icon?: ReactNode
  externalLink?: ReactNode
  getFilterInfo: GetFilterInfo
} & DimensionCellProps) => (
  <div className="break-all flex items-center gap-x-1">
    <DrilldownLink
      path={rootRoute.path}
      filterInfo={getFilterInfo(filterDimension, row)}
      icon={icon}
    >
      {text}
    </DrilldownLink>
    {externalLink}
  </div>
)
