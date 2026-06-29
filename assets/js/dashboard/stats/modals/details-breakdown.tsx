import React, {
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useState
} from 'react'
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
import { Metric, getBreakdownMetricLabel, isSortable } from '../metrics'
import { BreakdownTable } from './breakdown-table'
import { NonTimeDimension } from '../../stats-query'
import { useSiteContext } from '../../site-context'
import { DrilldownLink } from '../../components/drilldown-link'
import {
  ColumnConfiguration,
  MetricValueTooltipContent,
  SharedBreakdownReportProps,
  formatDateRangeLabel,
  useBodyPortalRef,
  extractMetricValue,
  GetFilterInfo,
  useColumnsHiddenForAllNull,
  dimensionOrderBy
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
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { SortButton } from '../../components/sort-button'
import { rootRoute } from '../../router'

type PaginatedData = { pages: QueryApiResponse[] }

type DetailsBreakdownProps = SharedBreakdownReportProps & {
  title: ReactNode
  defaultOrderBy?: MetricOrderBy
  searchEnabled?: boolean
  searchDimension?: NonTimeDimension
  onDataReady?: (data: PaginatedData) => void
  DimensionElement: (props: DimensionCellProps) => ReactNode
}

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

export function DetailsBreakdown({
  title,
  dimensionLabel,
  dimensions,
  metrics,
  alwaysOnFilters,
  defaultOrderBy = [] as MetricOrderBy,
  DimensionElement,
  searchEnabled = true,
  searchDimension,
  onDataReady,
  bundlePercentageWithVisitors = true,
  hideMetricsIfAllNull,
  getStatsQuery
}: DetailsBreakdownProps) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [search, setSearch] = useState('')

  const storedOrderBy = getStoredOrderBy({
    domain: site.domain,
    dimensionLabel,
    metrics,
    fallbackValue: defaultOrderBy
  })

  const { orderBy, orderByDictionary, toggleSortByMetric } = useMetricOrderBy({
    metrics,
    defaultOrderBy: storedOrderBy
  })

  useRememberOrderBy({
    effectiveOrderBy: orderBy,
    metrics,
    dimensionLabel
  })

  const statsReportQueryKey: StatsReportQueryKey = [
    dimensions.join(',') as StatsReportId,
    {
      dashboardState,
      reportParams: {
        metrics,
        dimensions,
        order_by: [
          ...(orderBy.length ? orderBy : storedOrderBy),
          ...dimensionOrderBy(dimensions)
        ],
        alwaysOnFilters
      },
      search,
      searchDimension
    }
  ]

  const apiState = useSearchAndPaginateQueryAPI(site, statsReportQueryKey, {
    getStatsQuery
  })

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

  const metricLabelFor = useCallback(
    (metric: Metric): string => {
      return getBreakdownMetricLabel(metric, {
        hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
        isRealtime: isRealTimeDashboard(dashboardState),
        dimensions: dimensions
      })
    },
    [dashboardState, dimensions]
  )

  const flattenedRows = useMemo(() => {
    return apiState.data?.pages.reduce<QueryResultRow[]>(
      (acc, p) => acc.concat(p.results),
      []
    )
  }, [apiState.data])
  const columnsHiddenForAllNull = useColumnsHiddenForAllNull(
    flattenedRows,
    query,
    hideMetricsIfAllNull
  )

  const columns: ColumnConfiguration<QueryResultRow>[] | null = useMemo(() => {
    if (!query) return null

    const filterDimension = query.dimensions[0] as NonTimeDimension

    const hasPercentage = query.metrics.includes('percentage')
    const isVisitorsWithPercentageCell = (m: Metric) =>
      bundlePercentageWithVisitors && hasPercentage && m === 'visitors'

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
      ...query.metrics
        .filter((metric) => {
          if (columnsHiddenForAllNull.has(metric)) return false
          return !(bundlePercentageWithVisitors && metric === 'percentage')
        })
        .map(
          (metric): ColumnConfiguration<QueryResultRow> => ({
            key: metric,
            renderLabel: () => (
              <MetricLabel
                label={metricLabelFor(metric)}
                warning={getMetricWarning(metric, meta)}
                sortable={isSortable(metric)}
                toggleSort={() => toggleSortByMetric(metric)}
                sortDirection={orderByDictionary[metric] ?? null}
              />
            ),
            renderCell: (row, isActive) => {
              if (isVisitorsWithPercentageCell(metric)) {
                return (
                  <VisitorsWithPercentageCell
                    row={row}
                    query={query}
                    isActive={isActive}
                  />
                )
              } else {
                return (
                  <MetricValueCell
                    row={row}
                    metric={metric}
                    metricLabel={metricLabelFor(metric)}
                    query={query}
                    isActive={isActive}
                  />
                )
              }
            },
            onSort: isSortable(metric)
              ? () => toggleSortByMetric(metric)
              : undefined,
            sortDirection: orderByDictionary[metric],
            width: isVisitorsWithPercentageCell(metric)
              ? 'w-36'
              : getMetricCellWidthClass(metric, metricLabelFor(metric)),
            align: 'right'
          })
        )
    ]
  }, [
    DimensionElement,
    dimensionLabel,
    query,
    meta,
    orderByDictionary,
    toggleSortByMetric,
    metricLabelFor,
    bundlePercentageWithVisitors,
    columnsHiddenForAllNull
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
      getRowKey={(row) => row.dimensions.join(',')}
    />
  )
}

function VisitorsWithPercentageCell({
  row,
  query,
  isActive
}: {
  row: QueryResultRow
  query: QueryResultQuery
  isActive?: boolean
}) {
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

function MetricValueCell({
  row,
  metric,
  metricLabel,
  query,
  isActive
}: {
  row: QueryResultRow
  metric: Metric
  metricLabel: string
  query: QueryResultQuery
  isActive?: boolean
}) {
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
  metricKey: string,
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
