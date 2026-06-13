import React, { useMemo, useState, useEffect, ReactNode } from 'react'
import FlipMove from 'react-flip-move'
import LazyLoader from '../../components/lazy-loader'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { ApiFilter, NonTimeDimension, OrderByEntry } from '../../stats-query'
import { Metric } from '../metrics'
import {
  ColumnConfiguration,
  MetricValueTooltipContent,
  formatDateRangeLabel,
  useBodyPortalRef,
  extractMetricValue,
  MetricValueWrapper,
  GetFilterInfo,
  BreakdownMetric,
  MetricElement,
  MetricElementProps
} from '../breakdowns'
import { DrilldownLink } from '../../components/drilldown-link'
import { QueryResultRow, QueryResultQuery, QueryApiResponse } from '../../api'
import classNames from 'classnames'
import { Tooltip } from '../../util/tooltip'
import { ChangeArrow } from './change-arrow'
import { MetricFormatterShort, MetricFormatterLong } from './metric-formatter'
import {
  StatsReportId,
  StatsReportQueryKey,
  useQueryApi
} from '../../hooks/use-query-api'

const MAX_ITEMS = 9
export const MIN_HEIGHT = 356
const ROW_HEIGHT = 32
const ROW_GAP_HEIGHT = 4
const DATA_CONTAINER_HEIGHT =
  (ROW_HEIGHT + ROW_GAP_HEIGHT) * (MAX_ITEMS - 1) + ROW_HEIGHT

export const DEFAULT_METRIC_COLUMN_WIDTH = 'w-16 min-w-16'
export const VISITORS_WITH_PERCENTAGE_COLUMN_WIDTH = 'w-32 min-w-32'

const BAR_METRIC = 'visitors'

type IndexBreakdownProps = {
  dimensions: NonTimeDimension[]
  dimensionLabel: string
  metrics: BreakdownMetric[]
  alwaysOnFilters?: ApiFilter[]
  DimensionElement: (props: DimensionCellWithBarProps) => ReactNode
  DefaultMetricElement?: MetricElement
  onDataReady?: (data: QueryApiResponse) => void
}

export function IndexBreakdown({
  metrics,
  dimensions,
  DimensionElement,
  DefaultMetricElement = MetricValueCell,
  dimensionLabel,
  alwaysOnFilters,
  onDataReady
}: IndexBreakdownProps) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [visible, setVisible] = useState(false)

  const metricSpecs = useMemo(
    () => metrics.map(({ key, label }) => ({ key, label })),
    [metrics]
  )

  const statsReportQueryKey: StatsReportQueryKey = [
    dimensions.join(',') as StatsReportId,
    {
      dashboardState,
      reportParams: {
        metrics: metricSpecs,
        dimensions,
        order_by: [
          ['visitors', 'desc'],
          ...dimensions.map((dim): OrderByEntry => [dim, 'asc'])
        ],
        alwaysOnFilters,
        pagination: { limit: MAX_ITEMS, offset: 0 }
      }
    }
  ]

  const { apiState, isRealtimeSilentUpdate } = useQueryApi(
    site,
    statsReportQueryKey,
    { enabled: visible }
  )

  useEffect(() => {
    if (apiState.data && typeof onDataReady === 'function') {
      onDataReady(apiState.data)
    }
  }, [apiState.data, onDataReady])

  const query: QueryResultQuery | null = apiState.data?.query ?? null

  const barMetricIndex = query
    ? query.metrics.findIndex((m) => m === BAR_METRIC)
    : null

  const barMaxValue = useMemo(() => {
    const rows = apiState.data?.results ?? []
    return barMetricIndex === null
      ? null
      : Math.max(...rows.map((r) => r.metrics[barMetricIndex] as number))
  }, [apiState.data, barMetricIndex])

  const columns = useMemo((): ColumnConfiguration<QueryResultRow>[] | null => {
    if (!query || barMetricIndex === null || barMaxValue === null) return null

    const filterDimension = query.dimensions[0] as NonTimeDimension

    // Render each spec in the declared order. Skip those whose
    // `canShowColumn` predicate returns false against the current data —
    // they were requested but hide themselves at render time.
    const visibleSpecs = apiState.data
      ? metrics.filter((spec) =>
          spec.canShowColumn ? spec.canShowColumn(apiState.data) : true
        )
      : metrics

    return [
      {
        key: 'dimension',
        renderLabel: () => dimensionLabel,
        renderCell: (row, isActive) => (
          <DimensionElement
            filterDimension={filterDimension}
            row={row}
            barWidthPercent={
              ((row.metrics[barMetricIndex] as number) / barMaxValue) * 100
            }
            isActive={isActive}
          />
        ),
        align: 'left'
      },
      ...visibleSpecs.map(
        ({ key, label, Cell, width }): ColumnConfiguration<QueryResultRow> => ({
          key,
          renderLabel: () => label,
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
          width,
          align: 'right'
        })
      )
    ]
  }, [
    dimensionLabel,
    DimensionElement,
    DefaultMetricElement,
    barMetricIndex,
    barMaxValue,
    query,
    metrics,
    apiState.data
  ])

  return (
    <LazyLoader onVisible={() => setVisible(true)}>
      <IndexBreakdownRenderer<QueryResultRow>
        {...apiState}
        rows={apiState.data?.results?.slice(0, MAX_ITEMS) ?? []}
        getDimensionValue={(row) => row.dimensions[0]}
        isRealtimeSilentUpdate={isRealtimeSilentUpdate}
        columns={columns}
      />
    </LazyLoader>
  )
}

/**
 * Convenience: takes a list of `BreakdownMetric`s and applies the
 * standard "bundle visitors+percentage" overlay — the visitors spec is
 * given `VisitorsWithPercentageCell` + the wider column width, and the
 * percentage spec is requested but hidden from the column list (the value
 * shows up inside the visitors cell). Specs that aren't `visitors` or
 * `percentage` are passed through unchanged. If either of the two is
 * absent, the input is returned as-is.
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

export type DimensionCellWithBarProps = {
  filterDimension: NonTimeDimension
  row: QueryResultRow
  barWidthPercent: number
  isActive?: boolean
}

export const DimensionCellWithBar = ({
  text,
  icon,
  onClick,
  externalLink,
  getFilterInfo,
  filterDimension,
  barWidthPercent,
  barClassName,
  row
}: {
  text: string
  icon?: ReactNode
  onClick?: () => void
  externalLink?: ReactNode
  getFilterInfo: GetFilterInfo
  barClassName: string
} & DimensionCellWithBarProps) => (
  <Bar barWidthPercent={barWidthPercent} className={barClassName}>
    <div className="flex justify-start items-center gap-x-1.5 w-full">
      <DrilldownLink
        onClick={onClick}
        filterInfo={getFilterInfo(filterDimension, row)}
        className="max-w-max w-full flex items-center md:overflow-hidden"
        icon={icon}
        textClassName="w-full md:truncate"
      >
        {text}
      </DrilldownLink>
      {externalLink}
    </div>
  </Bar>
)

export function VisitorsWithPercentageCell({
  row,
  query,
  isActive
}: MetricElementProps) {
  const portalRef = useBodyPortalRef()

  const { value: visitorsValue, comparison: visitorsComparison } =
    extractMetricValue(row, query, 'visitors')
  const { value: percentageValue, comparison: percentageComparison } =
    extractMetricValue(row, query, 'percentage')

  const visitorsShortFormatter = MetricFormatterShort['visitors']
  const visitorsLongFormatter = MetricFormatterLong['visitors']
  const percentageFormatter = MetricFormatterShort['percentage']

  const isVisitorsAbbreviated =
    visitorsValue !== null &&
    visitorsShortFormatter(visitorsValue) !==
      visitorsLongFormatter(visitorsValue)

  const showVisitorsTooltip = !!visitorsComparison || isVisitorsAbbreviated
  const showPercentageTooltip = !!percentageComparison

  const dateRangeLabel = formatDateRangeLabel(query.date_range)
  const comparisonDateRangeLabel = query.comparison_date_range
    ? formatDateRangeLabel(query.comparison_date_range)
    : null

  const percentageCell = (
    <span
      data-testid="metric-value"
      className={classNames('block w-full text-gray-500 dark:text-gray-400', {
        'translate-x-0 opacity-100 transition-all duration-150': isActive,
        'translate-x-[100%] opacity-0 transition-all duration-150 md:group-hover/report:translate-x-0 md:group-hover/report:opacity-100':
          !isActive
      })}
    >
      {percentageFormatter(percentageValue)}
      {percentageComparison && (
        <ChangeArrow
          change={percentageComparison.change}
          metric={'percentage' as Metric}
          className="inline-block pl-1 w-4"
          hideNumber
        />
      )}
    </span>
  )

  const percentageWithTooltip = showPercentageTooltip ? (
    <Tooltip
      containerRef={portalRef as React.RefObject<HTMLElement>}
      info={
        <MetricValueTooltipContent
          value={percentageValue}
          comparison={percentageComparison}
          metric={'percentage'}
          metricLabel="Percentage"
          dateRangeLabel={dateRangeLabel}
          comparisonDateRangeLabel={comparisonDateRangeLabel}
        />
      }
    >
      {percentageCell}
    </Tooltip>
  ) : (
    percentageCell
  )

  const visitorsCell = (
    <span
      className={classNames('block w-full', {
        'transition-transform duration-150 translate-x-0': isActive,
        'transition-transform duration-150 translate-x-[100%] md:group-hover/report:translate-x-0':
          !isActive
      })}
      data-testid="metric-value"
    >
      {visitorsShortFormatter(visitorsValue)}
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

  const visitorsWithTooltip = showVisitorsTooltip ? (
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
    <div
      className={
        'flex w-full font-medium text-sm block text-gray-800 dark:text-gray-200'
      }
    >
      <div className="w-1/2">{visitorsWithTooltip}</div>
      <div className="w-1/2">{percentageWithTooltip}</div>
    </div>
  )
}

export function MetricValueCell({
  row,
  metric,
  metricLabel,
  query
}: MetricElementProps) {
  const portalRef = useBodyPortalRef()

  const { value, comparison } = extractMetricValue(row, query, metric)

  const shortFormatter = MetricFormatterShort[metric]
  const longFormatter = MetricFormatterLong[metric]

  const isAbbreviated =
    value !== null && shortFormatter(value) !== longFormatter(value)
  const showTooltip = !!comparison || isAbbreviated

  const valueContent = (
    <MetricValueWrapper className={showTooltip ? 'cursor-default' : undefined}>
      {shortFormatter(value)}
      {comparison && (
        <ChangeArrow
          change={comparison.change}
          metric={metric}
          className="inline-block pl-1 w-4"
          hideNumber
        />
      )}
    </MetricValueWrapper>
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

export function IndexBreakdownRenderer<TRow>({
  rows,
  getDimensionValue,
  isPending,
  isPlaceholderData,
  isRealtimeSilentUpdate,
  columns
}: {
  rows: TRow[]
  getDimensionValue: (row: TRow) => string
  isPending: boolean
  isPlaceholderData: boolean
  isRealtimeSilentUpdate: boolean
  columns: ColumnConfiguration<TRow>[] | null
}) {
  const [tappedRow, setTappedRow] = useState<string | null>(null)

  if (!columns || isPending || (isPlaceholderData && !isRealtimeSilentUpdate)) {
    return (
      <div
        className="w-full flex flex-col justify-center"
        style={{ minHeight: `${MIN_HEIGHT}px` }}
      >
        <div className="mx-auto loading">
          <div />
        </div>
      </div>
    )
  }

  if (rows.length === 0) {
    return (
      <div
        className="w-full h-full flex flex-col justify-center"
        style={{ minHeight: `${MIN_HEIGHT}px` }}
      >
        <div className="mx-auto font-medium text-gray-500 dark:text-gray-400">
          No data yet
        </div>
      </div>
    )
  }

  return (
    <div className="h-full flex flex-col opacity-100 transition-opacity duration-300 starting:opacity-0">
      <div
        style={{ height: ROW_HEIGHT }}
        className="pt-3 w-full text-xs font-medium text-gray-500 dark:text-gray-400 flex items-center"
      >
        {columns.map((col) => (
          <div
            key={col.key}
            data-testid="report-header"
            className={classNames(
              col.width ?? 'grow w-full',
              col.align === 'right' ? 'text-right' : 'truncate'
            )}
          >
            {col.renderLabel()}
          </div>
        ))}
      </div>
      <div
        className="group/report"
        style={{ minHeight: DATA_CONTAINER_HEIGHT }}
      >
        <FlipMove disableAllAnimations={!isRealtimeSilentUpdate}>
          {rows.map((row) => {
            const dimensionValue = getDimensionValue(row)
            const isActive = tappedRow === dimensionValue

            const handleClick = (e: React.MouseEvent) => {
              if (
                window.innerWidth < 768 &&
                !(e.target as HTMLElement).closest('a')
              ) {
                setTappedRow(isActive ? null : dimensionValue)
              }
            }

            return (
              <div key={dimensionValue} style={{ minHeight: ROW_HEIGHT }}>
                <div
                  data-testid="report-row"
                  className="group/row flex w-full items-center hover:bg-gray-100/60 dark:hover:bg-gray-850 rounded-sm md:cursor-default cursor-pointer"
                  style={{ marginTop: ROW_GAP_HEIGHT }}
                  onClick={handleClick}
                >
                  {columns.map((col) => (
                    <div
                      key={col.key}
                      className={classNames(
                        col.width ?? 'grow w-full',
                        col.align === 'right' ? 'text-right' : 'md:truncate'
                      )}
                    >
                      {col.renderCell(row, isActive)}
                    </div>
                  ))}
                </div>
              </div>
            )
          })}
        </FlipMove>
      </div>
    </div>
  )
}

export const Bar = ({
  barWidthPercent,
  className,
  children
}: {
  barWidthPercent: number
  className: string
  children: ReactNode
}) => (
  <div className="w-full h-full relative">
    <div
      className={classNames(
        `absolute top-0 left-0 h-full rounded-sm dark:bg-gray-500/15 dark:group-hover/row:bg-gray-500/30`,
        className
      )}
      style={{ width: `${barWidthPercent}%` }}
    ></div>
    <div className="px-2 py-1.5 text-sm dark:text-gray-300 relative z-9 break-all">
      {children}
    </div>
  </div>
)
