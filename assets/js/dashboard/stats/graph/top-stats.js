import React from 'react'
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from 'classnames'
import { formatDateRange, formatDayShort, parseUTCDate } from '../../util/date'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { useLastLoadContext } from '../../last-load-context'
import { ChangeArrow } from '../reports/change-arrow'
import {
  MetricFormatterShort,
  MetricFormatterLong
} from '../reports/metric-formatter'

function topStatNumberShort(metric, value) {
  const formatter = MetricFormatterShort[metric]
  return formatter(value)
}

function topStatNumberLong(metric, value) {
  const formatter = MetricFormatterLong[metric]
  return formatter(value)
}

export default function TopStats({
  data,
  selectedMetric,
  onMetricClick,
  tooltipBoundary
}) {
  const { dashboardState } = useDashboardStateContext()
  const lastLoadTimestamp = useLastLoadContext()
  const site = useSiteContext()

  const isComparison =
    (dashboardState.comparison && data && data.comparingFrom !== null) || false

  function tooltip(stat) {
    let statName = stat.name.toLowerCase()
    const warning = warningText(stat.metric, site)
    statName = stat.value === 1 ? statName.replace(/s$/, '') : statName

    return (
      <div>
        {isComparison && (
          <div className="whitespace-nowrap">
            {topStatNumberLong(stat.metric, stat.value)} vs.{' '}
            {topStatNumberLong(stat.metric, stat.comparisonValue)} {statName}
          </div>
        )}

        {!isComparison && (
          <div className="whitespace-nowrap">
            {topStatNumberLong(stat.metric, stat.value)} {statName}
          </div>
        )}

        {stat.name === 'Current visitors' && (
          <p className="font-normal text-xs">
            Last updated{' '}
            <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp} />s ago
          </p>
        )}

        {warning ? (
          <p className="font-normal text-xs whitespace-nowrap">* {warning}</p>
        ) : null}
      </div>
    )
  }

  function warningText(metric) {
    const warning = data.meta.metric_warnings?.[metric]
    if (!warning) {
      return null
    }

    if (
      metric === 'bounce_rate' &&
      warning.code === 'no_imported_bounce_rate'
    ) {
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

  function blinkingDot() {
    return (
      <div
        key="dot"
        className="block pulsating-circle"
        style={{ left: '125px', top: '52px' }}
      ></div>
    )
  }

  function renderStatName(stat, isSelected) {
    const [statDisplayName, statExtraName] = stat.name.split(/(\(.+\))/g)

    const statDisplayNameClass = classNames(
      'text-xs uppercase whitespace-nowrap flex w-fit',
      {
        'text-gray-900 dark:text-gray-100 font-bold tracking-[-.01em]':
          isSelected,
        'font-semibold text-gray-500 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-100':
          !isSelected
      }
    )

    return (
      <div className={statDisplayNameClass}>
        {statDisplayName}
        {statExtraName && (
          <span className="hidden sm:inline-block ml-1">{statExtraName}</span>
        )}
        {warningText(stat.metric) && (
          <span className="inline-block ml-1">*</span>
        )}
      </div>
    )
  }

  function renderStat(stat, index) {
    const isSelected = stat.graphable && stat.metric === selectedMetric

    const className = classNames(
      'lg:flex-1 px-4 w-1/2 my-2 lg:w-auto group select-none',
      {
        'cursor-pointer': stat.graphable,
        'lg:border-l border-gray-200 dark:border-gray-750': index > 0,
        'border-r lg:border-r-0': index % 2 === 0
      }
    )
    return (
      <Tooltip
        key={stat.name}
        info={tooltip(stat, dashboardState)}
        className={className}
        onClick={stat.graphable ? () => onMetricClick(stat.metric) : () => {}}
        boundary={tooltipBoundary}
      >
        <div
          className={classNames(
            'flex flex-col gap-y-1 p-2 -mx-2 rounded-md hover:bg-gray-100/80 dark:hover:bg-gray-800',
            {
              'bg-gray-100/70 dark:bg-gray-800': isSelected
            }
          )}
        >
          {renderStatName(stat, isSelected)}
          <div>
            <span className="flex items-baseline whitespace-nowrap">
              <p
                className="font-semibold text-[1.2rem] text-gray-900 dark:text-gray-100"
                id={
                  stat.name === 'Current visitors'
                    ? 'current_visitors'
                    : stat.metric
                }
              >
                {topStatNumberShort(stat.metric, stat.value)}
              </p>
              {stat.change != null ? (
                <ChangeArrow
                  metric={stat.metric}
                  change={stat.change}
                  className="ml-2 text-xs font-medium text-gray-500 dark:text-gray-100"
                />
              ) : null}
            </span>
            {isComparison ? (
              <p className="text-xs dark:text-gray-100 font-medium">
                {data.timeRange
                  ? `${formatDayShort(parseUTCDate(data.from))}, ${data.timeRange}`
                  : formatDateRange(site, data.from, data.to)}
              </p>
            ) : null}
          </div>

          {isComparison ? (
            <div className="mt-1">
              <p
                id={`previous-${stat.metric}`}
                className="font-semibold text-[1.2rem] text-gray-500/80 dark:text-gray-400"
              >
                {topStatNumberShort(stat.metric, stat.comparisonValue)}
              </p>
              <p className="text-xs text-gray-500 dark:text-gray-400 font-medium">
                {data.comparisonTimeRange
                  ? `${formatDayShort(parseUTCDate(data.comparingFrom))}, ${data.comparisonTimeRange}`
                  : formatDateRange(site, data.comparingFrom, data.comparingTo)}
              </p>
            </div>
          ) : null}
        </div>
      </Tooltip>
    )
  }

  const stats =
    data && data.topStats.filter((stat) => stat.value !== null).map(renderStat)

  if (stats && dashboardState.period === 'realtime') {
    stats.push(blinkingDot())
  }

  return stats ? <>{stats}</> : null
}
