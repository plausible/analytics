import React, { ReactNode } from 'react'
import classNames from 'classnames'
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import { formatDateRange, formatDayShort, parseUTCDate } from '../../util/date'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { useLastLoadContext } from '../../last-load-context'
import { useCurrentVisitorsContext } from '../../current-visitors-context'
import { ChangeArrow } from '../reports/change-arrow'
import {
  MetricFormatterLong,
  MetricFormatterShort,
  ValueType
} from '../reports/metric-formatter'
import { isRealTimeDashboard } from '../../util/filters'
import { QueryApiResponse, QueryResultMeta } from '../../api'
import { Metric, MetricSpec } from '../metrics'
import { formatTopStatsData, TopStatItem } from './fetch-top-stats'

type TopStatsProps = {
  data: QueryApiResponse
  selectedMetric: MetricSpec
  onMetricClick: (metric: MetricSpec) => void
  tooltipBoundaryRef: React.RefObject<HTMLDivElement>
}

export default function TopStats({
  data,
  selectedMetric,
  onMetricClick,
  tooltipBoundaryRef
}: TopStatsProps) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  const lastLoadTimestamp = useLastLoadContext()
  const currentVisitors = useCurrentVisitorsContext()

  const {
    topStats,
    meta,
    from,
    to,
    comparingFrom,
    comparingTo,
    timeRange,
    comparisonTimeRange
  } = formatTopStatsData(data)

  const isComparison =
    (dashboardState.comparison && comparingFrom !== null) || false
  const isRealtime = isRealTimeDashboard(dashboardState)

  const visibleStats: TopStatItem[] = topStats.filter(
    (stat) => stat.value !== null
  )

  return (
    <>
      {isRealtime && currentVisitors !== null && (
        <TopStatTile
          warning={null}
          key={'current_visitors'}
          label={'Current visitors'}
          formatValueShort={MetricFormatterShort['visitors']}
          formatValueLong={MetricFormatterLong['visitors']}
          isSelected={false}
          isComparison={isComparison}
          site={site}
          from={from}
          to={to}
          timeRange={timeRange}
          comparingFrom={comparingFrom}
          comparingTo={comparingTo}
          comparisonTimeRange={comparisonTimeRange}
          lastLoadTimestamp={lastLoadTimestamp}
          tooltipBoundaryRef={tooltipBoundaryRef}
          id={'current_visitors'}
          value={currentVisitors}
        />
      )}
      {visibleStats.map((stat) => (
        <TopStatTile
          warning={getWarningText(meta, stat.metricSpec.key)}
          label={stat.metricSpec.label}
          key={stat.metricSpec.key}
          id={stat.metricSpec.key}
          labelSuffix={stat.labelSuffix}
          formatValueShort={MetricFormatterShort[stat.metricSpec.key]}
          formatValueLong={MetricFormatterLong[stat.metricSpec.key]}
          isSelected={
            stat.graphable && stat.metricSpec.key === selectedMetric.key
          }
          isComparison={isComparison}
          site={site}
          from={from}
          to={to}
          timeRange={timeRange}
          comparingFrom={comparingFrom}
          comparingTo={comparingTo}
          comparisonTimeRange={comparisonTimeRange}
          lastLoadTimestamp={null}
          onClick={
            stat.graphable ? () => onMetricClick(stat.metricSpec) : undefined
          }
          tooltipBoundaryRef={tooltipBoundaryRef}
          value={stat.value}
          change={stat.change}
          comparisonValue={stat.comparisonValue}
        />
      ))}
      {isRealtime && visibleStats.length > 0 && <BlinkingDot />}
    </>
  )
}

type TopStatTileProps = {
  id: string
  label: string
  warning: string | null
  isSelected: boolean
  isComparison: boolean
  site: PlausibleSite
  from: string
  to: string
  timeRange: string | null
  comparingFrom: string | null
  comparingTo: string | null
  comparisonTimeRange: string | null
  lastLoadTimestamp: Date | null
  onClick?: () => void
  tooltipBoundaryRef: React.RefObject<HTMLDivElement>
  formatValueLong: (value: ValueType) => string
  formatValueShort: (value: ValueType) => string
} & Pick<TopStatItem, 'value' | 'change' | 'comparisonValue' | 'labelSuffix'>

function TopStatTile({
  id,
  value,
  label,
  labelSuffix,
  change,
  comparisonValue,
  isSelected,
  isComparison,
  warning,
  site,
  from,
  to,
  timeRange,
  formatValueShort,
  formatValueLong,
  comparingFrom,
  comparingTo,
  comparisonTimeRange,
  lastLoadTimestamp,
  onClick,
  tooltipBoundaryRef
}: TopStatTileProps) {
  const containerClass = classNames(
    'lg:flex-1 px-4 w-1/2 my-2 lg:w-auto group select-none',
    'border-gray-200 dark:border-gray-750',
    'odd:border-r lg:odd:border-r-0 lg:not-first:border-l',
    { 'cursor-pointer': typeof onClick === 'function' }
  )

  return (
    <Tooltip
      info={
        <TopStatsTooltipContent
          isComparison={isComparison}
          formattedValue={formatValueLong(value)}
          formattedComparisonValue={
            comparisonValue !== undefined
              ? formatValueLong(comparisonValue)
              : null
          }
          metricLabel={label}
          isSingular={value === 1}
          warning={warning}
        >
          {lastLoadTimestamp !== null && (
            <p className="font-normal text-xs">
              Last updated{' '}
              <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp} />s
              ago
            </p>
          )}
        </TopStatsTooltipContent>
      }
      className={containerClass}
      onClick={onClick ?? undefined}
      boundary={tooltipBoundaryRef.current}
    >
      <div
        className={classNames(
          'flex flex-col gap-y-1 p-2 -mx-2 rounded-md hover:bg-gray-100/80 dark:hover:bg-gray-800',
          { 'bg-gray-100/70 dark:bg-gray-800': isSelected }
        )}
      >
        <TopStatLabel
          label={`${label}${labelSuffix ?? ''}`}
          isSelected={isSelected}
          hasWarning={!!warning}
        />
        <div>
          <span className="flex items-baseline whitespace-nowrap">
            <p
              className="font-semibold text-[1.2rem] text-gray-900 dark:text-gray-100"
              id={id}
            >
              {formatValueShort(value)}
            </p>
            {change != null && (
              <ChangeArrow
                metric={id as Metric}
                change={change}
                className="ml-2 text-xs font-medium text-gray-500 dark:text-gray-100"
              />
            )}
          </span>
          {isComparison && (
            <p className="text-xs dark:text-gray-100 font-medium">
              {timeRange
                ? `${formatDayShort(parseUTCDate(from))}, ${timeRange}`
                : formatDateRange(site, from, to)}
            </p>
          )}
        </div>

        {isComparison &&
          comparisonValue !== undefined &&
          comparingFrom &&
          comparingTo && (
            <div className="mt-1">
              <p
                id={`previous-${id}`}
                className="font-semibold text-[1.2rem] text-gray-500/80 dark:text-gray-400"
              >
                {formatValueShort(comparisonValue)}
              </p>
              <p className="text-xs text-gray-500 dark:text-gray-400 font-medium">
                {comparisonTimeRange
                  ? `${formatDayShort(parseUTCDate(comparingFrom))}, ${comparisonTimeRange}`
                  : formatDateRange(site, comparingFrom, comparingTo)}
              </p>
            </div>
          )}
      </div>
    </Tooltip>
  )
}

type TopStatLabelProps = {
  label: string
  isSelected: boolean
  hasWarning: boolean
}

function TopStatLabel({ label, isSelected, hasWarning }: TopStatLabelProps) {
  // "Unique visitors (last 30 min)" -> ["Unique visitors", "(last 30 min)"]
  const [displayName, extraName] = label.split(/(\(.+\))/g)
  const className = classNames(
    'text-xs uppercase whitespace-nowrap flex w-fit',
    {
      'text-gray-900 dark:text-gray-100 font-bold tracking-[-.01em]':
        isSelected,
      'font-semibold text-gray-500 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-100':
        !isSelected
    }
  )

  return (
    <div className={className}>
      {displayName}
      {extraName && (
        <span className="hidden sm:inline-block ml-1">{extraName}</span>
      )}
      {hasWarning && <span className="inline-block ml-1">*</span>}
    </div>
  )
}

type TopStatsTooltipContentProps = {
  isComparison: boolean
  formattedValue: string
  formattedComparisonValue: string | null
  metricLabel: string
  isSingular: boolean
  warning: string | null
  children?: ReactNode
}

function TopStatsTooltipContent({
  isComparison,
  formattedValue,
  formattedComparisonValue,
  metricLabel,
  isSingular,
  warning,
  children
}: TopStatsTooltipContentProps) {
  const lowerLabel = metricLabel.toLowerCase()
  // crude singularization: "visitors" -> "visitor" when value === 1
  const inflectedLabel = isSingular ? lowerLabel.replace(/s$/, '') : lowerLabel

  return (
    <div>
      <div className="whitespace-nowrap">
        {isComparison
          ? `${formattedValue} vs. ${formattedComparisonValue} ${inflectedLabel}`
          : `${formattedValue} ${inflectedLabel}`}
      </div>
      {children}
      {warning && (
        <p className="font-normal text-xs whitespace-nowrap">* {warning}</p>
      )}
    </div>
  )
}

function BlinkingDot() {
  return (
    <div
      className="block pulsating-circle"
      style={{ left: '125px', top: '52px' }}
    />
  )
}

function getWarningText(meta: QueryResultMeta, metric: Metric): string | null {
  const warning = meta.metric_warnings?.[metric]
  if (!warning) return null

  if (metric === 'bounce_rate' && warning.code === 'no_imported_bounce_rate') {
    return 'Does not include imported data'
  }
  if (
    metric === 'scroll_depth' &&
    warning.code === 'no_imported_scroll_depth'
  ) {
    return 'Does not include imported data'
  }
  if (metric === 'time_on_page') {
    return warning.message
  }
  return null
}
