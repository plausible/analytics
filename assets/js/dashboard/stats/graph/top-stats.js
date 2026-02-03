import React from 'react'
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { formatDateRange } from '../../util/date'
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

export function TopStats({ data, onMetricUpdate, tooltipBoundary }) {
  const { dashboardState } = useDashboardStateContext()
  const lastLoadTimestamp = useLastLoadContext()
  const site = useSiteContext()

  const isComparison =
    (dashboardState.comparison && data && data.comparingFrom !== null) || false

  function tooltip(stat) {
    let statName = stat.name.toLowerCase()
    const warning = warningText(stat.metric, site)
    statName = stat.value === 1 ? statName.slice(0, -1) : statName

    return (
      <div>
        {isComparison && (
          <div className="whitespace-nowrap">
            {topStatNumberLong(stat.metric, stat.value)} vs.{' '}
            {topStatNumberLong(stat.metric, stat.comparisonValue)} {statName}
            <ChangeArrow
              metric={stat.metric}
              change={stat.change}
              className="pl-4 text-xs text-gray-100"
            />
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

  function canMetricBeGraphed(stat) {
    return stat.graphable
  }

  function maybeUpdateMetric(stat) {
    if (canMetricBeGraphed(stat)) {
      storage.setItem(`metric__${site.domain}`, stat.metric)
      onMetricUpdate(stat.metric)
    }
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

  function getStoredMetric() {
    return storage.getItem(`metric__${site.domain}`)
  }

  function renderStatName(stat) {
    const isSelected = stat.graphable && stat.metric === getStoredMetric()

    const [statDisplayName, statExtraName] = stat.name.split(/(\(.+\))/g)

    const statDisplayNameClass = classNames(
      'text-xs text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-fit border-b',
      {
        'text-indigo-600 dark:text-indigo-500 font-bold tracking-[-.01em] border-indigo-600 dark:border-indigo-500':
          isSelected,
        'font-semibold group-hover:text-indigo-700 dark:group-hover:text-indigo-500 border-transparent':
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
    const className = classNames(
      'px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none',
      {
        'cursor-pointer': canMetricBeGraphed(stat),
        'lg:border-l border-gray-300 dark:border-gray-700': index > 0,
        'border-r lg:border-r-0': index % 2 === 0
      }
    )

    return (
      <Tooltip
        key={stat.name}
        info={tooltip(stat, dashboardState)}
        className={className}
        onClick={() => {
          maybeUpdateMetric(stat)
        }}
        boundary={tooltipBoundary}
      >
        {renderStatName(stat)}
        <div className="my-1 space-y-2">
          <div>
            <span className="flex items-center justify-between whitespace-nowrap">
              <p
                className="font-bold text-xl dark:text-gray-100"
                id={stat.metric}
              >
                {topStatNumberShort(stat.metric, stat.value)}
              </p>
              {!isComparison && stat.change != null ? (
                <ChangeArrow
                  metric={stat.metric}
                  change={stat.change}
                  className="pl-2 text-xs dark:text-gray-100"
                />
              ) : null}
            </span>
            {isComparison ? (
              <p className="text-xs dark:text-gray-100">
                {formatDateRange(site, data.from, data.to)}
              </p>
            ) : null}
          </div>

          {isComparison ? (
            <div>
              <p className="font-bold text-xl text-gray-500 dark:text-gray-400">
                {topStatNumberShort(stat.metric, stat.comparisonValue)}
              </p>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                {formatDateRange(site, data.comparingFrom, data.comparingTo)}
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

  return stats || null
}
