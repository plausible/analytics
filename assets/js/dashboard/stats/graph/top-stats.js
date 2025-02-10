/** @format */

import React from 'react'
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { formatDateRange } from '../../util/date'
import { getGraphableMetrics } from './graph-util'
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

export default function TopStats({ data, onMetricUpdate, tooltipBoundary }) {
  const { query } = useQueryContext()
  const lastLoadTimestamp = useLastLoadContext()
  const site = useSiteContext()

  const isComparison = query.comparison && data && data.comparing_from

  function tooltip(stat) {
    let statName = stat.name.toLowerCase()
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

        {stat.name === 'Scroll depth' &&
          data.meta.metric_warnings?.scroll_depth?.code === 'no_imported_scroll_depth' && (
            <p className="font-normal text-xs whitespace-nowrap">
              * Does not include imported data
            </p>
          )}
      </div>
    )
  }

  function canMetricBeGraphed(stat) {
    const graphableMetrics = getGraphableMetrics(query, site)
    return graphableMetrics.includes(stat.graph_metric)
  }

  function maybeUpdateMetric(stat) {
    if (canMetricBeGraphed(stat)) {
      storage.setItem(`metric__${site.domain}`, stat.graph_metric)
      onMetricUpdate(stat.graph_metric)
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
    const isSelected = stat.graph_metric === getStoredMetric()

    const [statDisplayName, statExtraName] = stat.name.split(/(\(.+\))/g)

    const statDisplayNameClass = classNames(
      'text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-content border-b',
      {
        'text-indigo-700 dark:text-indigo-500 border-indigo-700 dark:border-indigo-500':
          isSelected,
        'group-hover:text-indigo-700 dark:group-hover:text-indigo-500 border-transparent':
          !isSelected
      }
    )

    return (
      <div className={statDisplayNameClass}>
        {statDisplayName}
        {statExtraName && (
          <span className="hidden sm:inline-block ml-1">{statExtraName}</span>
        )}
        {stat.warning_code && <span className="inline-block ml-1">*</span>}
      </div>
    )
  }

  function renderStat(stat, index) {
    const className = classNames(
      'px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none',
      {
        'cursor-pointer': canMetricBeGraphed(stat),
        'lg:border-l border-gray-300': index > 0,
        'border-r lg:border-r-0': index % 2 === 0
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
      >
        {renderStatName(stat)}
        <div className="my-1 space-y-2">
          <div>
            <span className="flex items-center justify-between whitespace-nowrap">
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
                {topStatNumberShort(stat.graph_metric, stat.comparison_value)}
              </p>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                {formatDateRange(site, data.comparing_from, data.comparing_to)}
              </p>
            </div>
          ) : null}
        </div>
      </Tooltip>
    )
  }

  const stats = data && data.top_stats.map(renderStat)

  if (stats && query.period === 'realtime') {
    stats.push(blinkingDot())
  }

  return stats || null
}
