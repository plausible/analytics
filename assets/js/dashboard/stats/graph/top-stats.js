import React from 'react'
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { formatDateRange } from '../../util/date'
import { useQueryContext } from '../../query-context'
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
  onMetricUpdate,
  tooltipBoundary,
  graphableMetrics
}) {
  const { query } = useQueryContext()
  const lastLoadTimestamp = useLastLoadContext()
  const site = useSiteContext()

  const isComparison = query.comparison && data && data.comparing_from

  function tooltip(stat) {
    let statName = stat.name.toLowerCase()
    const warning = warningText(stat.graph_metric, site)
    statName = stat.value === 1 ? statName.slice(0, -1) : statName

    return (
      <div>
        {isComparison && (
          <div className="whitespace-nowrap">
            {topStatNumberLong(stat.graph_metric, stat.value)} vs.{' '}
            {topStatNumberLong(stat.graph_metric, stat.comparison_value)}{' '}
            {statName}
            <ChangeArrow
              metric={stat.graph_metric}
              change={stat.change}
              className="pl-4 text-xs text-gray-100"
            />
          </div>
        )}

        {!isComparison && (
          <div className="whitespace-nowrap">
            {topStatNumberLong(stat.graph_metric, stat.value)} {statName}
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
    return graphableMetrics.includes(stat.graph_metric)
  }

  function maybeUpdateMetric(stat) {
    if (canMetricBeGraphed(stat)) {
      storage.setItem(`metric__${site.domain}`, stat.graph_metric)
      onMetricUpdate(stat.graph_metric)
    }
  }

  function getStoredMetric() {
    return storage.getItem(`metric__${site.domain}`)
  }

  function renderStatName(stat) {
    const isSelected = stat.graph_metric === getStoredMetric()

    const [statDisplayName, statExtraName] = stat.name.split(/(\(.+\))/g)

    const statDisplayNameClass = classNames(
      'text-xs font-bold text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-fit',
      {
        'text-gray-900 dark:text-gray-100':
          isSelected,
        'group-hover:text-gray-900 dark:group-hover:text-gray-100 border-transparent':
          !isSelected
      }
    )

    return (
      <div className={statDisplayNameClass}>
        {statDisplayName}
        {statExtraName && (
          <span className="hidden sm:inline-block ml-1">{statExtraName}</span>
        )}
        {warningText(stat.graph_metric) && (
          <span className="inline-block ml-1">*</span>
        )}
      </div>
    )
  }

  function renderStat(stat, index) {
    const isSelected = stat.graph_metric === getStoredMetric()

    const className = classNames(
      'group flex-1 -mb-px p-5 w-1/2 lg:w-auto hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-b-2 hover:border-b-gray-250 dark:hover:border-b-gray-500 active:bg-gray-100 dark:active:bg-gray-700 transition-all duration-150 select-none',
      {
        'cursor-pointer': canMetricBeGraphed(stat),
        'border-b-2 border-b-gray-800 dark:border-b-gray-500': isSelected
      }
    )

    return (
      <Tooltip
        key={stat.name}
        info={tooltip(stat, query)}
        className={className}
        onClick={() => {
          maybeUpdateMetric(stat)
        }}
        boundary={tooltipBoundary}
        delayed
      >
        {renderStatName(stat)}
        <div className="mt-1.5 space-y-2">
          <div>
            <span className="flex items-baseline gap-x-2 whitespace-nowrap">
              <p
                className="font-bold text-xl dark:text-gray-100"
                id={stat.graph_metric}
              >
                {topStatNumberShort(stat.graph_metric, stat.value)}
              </p>
              {!isComparison && stat.change != null ? (
                <ChangeArrow
                  metric={stat.graph_metric}
                  change={stat.change}
                  className="text-xs dark:text-gray-100"
                />
              ) : null}
            </span>
            {isComparison ? (
              <p className="text-xs font-medium dark:text-gray-100">
                {formatDateRange(site, data.from, data.to)}
              </p>
            ) : null}
          </div>

          {isComparison ? (
            <div>
              <p className="font-bold text-xl text-gray-500 dark:text-gray-400">
                {topStatNumberShort(stat.graph_metric, stat.comparison_value)}
              </p>
              <p className="text-xs font-medium text-gray-500 dark:text-gray-400">
                {formatDateRange(site, data.comparing_from, data.comparing_to)}
              </p>
            </div>
          ) : null}
        </div>
      </Tooltip>
    )
  }

  const stats =
    data && data.top_stats.filter((stat) => stat.value !== null).map(renderStat)

  return stats || null
}
