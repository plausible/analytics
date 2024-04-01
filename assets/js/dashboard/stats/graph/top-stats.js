import React from "react";
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from "classnames";
import numberFormatter, { durationFormatter } from '../../util/number-formatter'
import * as storage from '../../util/storage'
import { formatDateRange } from '../../util/date.js'
import { getGraphableMetrics } from "./graph-util.js";

function Maybe({condition, children}) {
  if (condition) {
    return children
  } else {
    return null
  }
}

function renderPercentageComparison(name, comparison, forceDarkBg = false) {
  const formattedComparison = numberFormatter(Math.abs(comparison))

  const defaultClassName = classNames({
     "pl-2 text-xs dark:text-gray-100": !forceDarkBg,
     "pl-2 text-xs text-gray-100": forceDarkBg
   })

   const noChangeClassName = classNames({
     "pl-2 text-xs text-gray-700 dark:text-gray-300": !forceDarkBg,
     "pl-2 text-xs text-gray-300": forceDarkBg
   })

  if (comparison > 0) {
    const color = name === 'Bounce rate' ? 'text-red-400' : 'text-green-500'
    return <span className={defaultClassName}><span className={color + ' font-bold'}>&uarr;</span> {formattedComparison}%</span>
  } else if (comparison < 0) {
    const color = name === 'Bounce rate' ? 'text-green-500' : 'text-red-400'
    return <span className={defaultClassName}><span className={color + ' font-bold'}>&darr;</span> {formattedComparison}%</span>
  } else if (comparison === 0) {
    return <span className={noChangeClassName}>&#12336; 0%</span>
  } else {
    return null
  }
}

function topStatNumberShort(name, value) {
  if (['visit duration', 'time on page'].includes(name.toLowerCase())) {
    return durationFormatter(value)
  } else if (['bounce rate', 'conversion rate'].includes(name.toLowerCase())) {
    return value + '%'
  } else if (['average revenue', 'total revenue'].includes(name.toLowerCase())) {
    return value?.short
  } else {
    return numberFormatter(value)
  }
}

function topStatNumberLong(name, value) {
  if (['visit duration', 'time on page'].includes(name.toLowerCase())) {
    return durationFormatter(value)
  } else if (['bounce rate', 'conversion rate'].includes(name.toLowerCase())) {
    return value + '%'
  } else if (['average revenue', 'total revenue'].includes(name.toLowerCase())) {
    return value?.long
  } else {
    return (value || 0).toLocaleString()
  }
}

export default function TopStats(props) {
  const {site, query, data, onMetricUpdate, tooltipBoundary, lastLoadTimestamp} = props

  function tooltip(stat) {
    let statName = stat.name.toLowerCase()
    statName = stat.value === 1 ? statName.slice(0, -1) : statName

    return (
      <div>
        {query.comparison && <div className="whitespace-nowrap">
          {topStatNumberLong(stat.name, stat.value)} vs. {topStatNumberLong(stat.name, stat.comparison_value)} {statName}
          <span className="ml-2">{renderPercentageComparison(stat.name, stat.change, true)}</span>
        </div>}

        {!query.comparison && <div className="whitespace-nowrap">
          {topStatNumberLong(stat.name, stat.value)} {statName}
        </div>}

        {stat.name === 'Current visitors' && <p className="font-normal text-xs">Last updated <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp}/>s ago</p>}
      </div>
    )
  }

  function canMetricBeGraphed(stat) {
    const graphableMetrics = getGraphableMetrics(query, site)
    return stat.graph_metric && graphableMetrics.includes(stat.graph_metric)
  }

  function maybeUpdateMetric(stat) {
    if (canMetricBeGraphed(stat)) {
      storage.setItem(`metric__${site.domain}`, stat.graph_metric)
      onMetricUpdate(stat.graph_metric)
    }
  }

  function blinkingDot() {
    return (
      <div key="dot" className="block pulsating-circle" style={{ left: '125px', top: '52px' }}></div>
    )
  }

  function getStoredMetric() {
    return storage.getItem(`metric__${site.domain}`)
  }

  function renderStatName(stat) {
    const isSelected = stat.graph_metric === getStoredMetric()

    const [statDisplayName, statExtraName] = stat.name.split(/(\(.+\))/g)

    const statDisplayNameClass = classNames('text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-content border-b', {
      'text-indigo-700 dark:text-indigo-500 border-indigo-700 dark:border-indigo-500': isSelected,
      'group-hover:text-indigo-700 dark:group-hover:text-indigo-500 border-transparent': !isSelected
    })

    return(
      <div className={statDisplayNameClass}>
        {statDisplayName}
        {statExtraName && <span className="hidden sm:inline-block ml-1">{statExtraName}</span>}
      </div>
    )
  }

  function renderStat(stat, index) {
    const className = classNames('px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none', {
      'cursor-pointer': canMetricBeGraphed(stat),
      'lg:border-l border-gray-300': index > 0,
      'border-r lg:border-r-0': index % 2 === 0
    })

    return (
      <Tooltip key={stat.name} info={tooltip(stat, query)} className={className} onClick={() => { maybeUpdateMetric(stat) }} boundary={tooltipBoundary}>
        {renderStatName(stat)}
        <div className="my-1 space-y-2">
          <div>
            <span className="flex items-center justify-between whitespace-nowrap">
              <p className="font-bold text-xl dark:text-gray-100" id={stat.graph_metric}>{topStatNumberShort(stat.name, stat.value)}</p>
              <Maybe condition={!query.comparison}>
                { renderPercentageComparison(stat.name, stat.change) }
              </Maybe>
            </span>
              <Maybe condition={query.comparison}>
                <p className="text-xs dark:text-gray-100">{ formatDateRange(site, data.from, data.to) }</p>
              </Maybe>
          </div>

          <Maybe condition={query.comparison}>
            <div>
              <p className="font-bold text-xl text-gray-500 dark:text-gray-400">{ topStatNumberShort(stat.name, stat.comparison_value) }</p>
              <p className="text-xs text-gray-500 dark:text-gray-400">{ formatDateRange(site, data.comparing_from, data.comparing_to) }</p>
            </div>
          </Maybe>
        </div>
      </Tooltip>
    )
  }

  const stats = data && data.top_stats.map(renderStat)

  if (stats && query.period === 'realtime') {
    stats.push(blinkingDot())
  }

  return stats || null;
}
