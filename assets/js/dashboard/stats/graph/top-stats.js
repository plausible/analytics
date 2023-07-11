import React from "react";
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from "classnames";
import numberFormatter, { durationFormatter } from '../../util/number-formatter'
import { METRIC_MAPPING } from './graph-util'
import { formatDateRange } from '../../util/date.js'

function Maybe({condition, children}) {
  if (condition) {
    return children
  } else {
    return null
  }
}

export default class TopStats extends React.Component {
  renderPercentageComparison(name, comparison, forceDarkBg = false) {
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

  topStatNumberShort(name, value) {
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

  topStatNumberLong(name, value) {
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

  topStatTooltip(stat, query) {
    let statName = stat.name.toLowerCase()
    statName = stat.value === 1 ? statName.slice(0, -1) : statName

    const { topStatData, lastLoadTimestamp } = this.props
    const showingImported = topStatData?.imported_source && topStatData?.with_imported

    return (
      <div>
        {query.comparison && <div className="whitespace-nowrap">
          {this.topStatNumberLong(stat.name, stat.value)} vs. {this.topStatNumberLong(stat.name, stat.comparison_value)} {statName}
          <span className="ml-2">{this.renderPercentageComparison(stat.name, stat.change, true)}</span>
        </div>}

        {!query.comparison && <div className="whitespace-nowrap">
          {this.topStatNumberLong(stat.name, stat.value)} {statName}
        </div>}

        {stat.name === 'Current visitors' && <p className="font-normal text-xs">Last updated <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp}/>s ago</p>}
        {stat.name === 'Views per visit' && showingImported && <p className="font-normal text-xs whitespace-nowrap">Based only on native data</p>}
      </div>
    )
  }

  canMetricBeGraphed(stat) {
    const isTotalUniqueVisitors = this.props.query.filters.goal && stat.name === 'Unique visitors'
    const isKnownMetric = Object.keys(METRIC_MAPPING).includes(stat.name)

    return isKnownMetric && !isTotalUniqueVisitors
  }

  maybeUpdateMetric(stat) {
    if (this.canMetricBeGraphed(stat)) {
      this.props.updateMetric(METRIC_MAPPING[stat.name])
    }
  }

  blinkingDot() {
    return (
      <div key="dot" className="block pulsating-circle" style={{ left: '125px', top: '52px' }}></div>
    )
  }

  renderStatName(stat) {
    const { metric } = this.props
    const isSelected = metric === METRIC_MAPPING[stat.name]

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

  render() {
    const { topStatData, query, site } = this.props

    const stats = topStatData && topStatData.top_stats.map((stat, index) => {

      const className = classNames('px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none', {
        'cursor-pointer': this.canMetricBeGraphed(stat),
        'lg:border-l border-gray-300': index > 0,
        'border-r lg:border-r-0': index % 2 === 0
      })

      return (
          <Tooltip key={stat.name} info={this.topStatTooltip(stat, query)} className={className} onClick={() => { this.maybeUpdateMetric(stat) }} boundary={this.props.tooltipBoundary}>
            {this.renderStatName(stat)}
            <div className="my-1 space-y-2">
              <div>
                <span className="flex items-center justify-between whitespace-nowrap">
                  <p className="font-bold text-xl dark:text-gray-100" id={METRIC_MAPPING[stat.name]}>{this.topStatNumberShort(stat.name, stat.value)}</p>
                  <Maybe condition={!query.comparison}>
                    { this.renderPercentageComparison(stat.name, stat.change) }
                  </Maybe>
                </span>
                  <Maybe condition={query.comparison}>
                    <p className="text-xs dark:text-gray-100">{ formatDateRange(site, topStatData.from, topStatData.to) }</p>
                  </Maybe>
              </div>

              <Maybe condition={query.comparison}>
                <div>
                  <p className="font-bold text-xl text-gray-500 dark:text-gray-400">{ this.topStatNumberShort(stat.name, stat.comparison_value) }</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">{ formatDateRange(site, topStatData.comparing_from, topStatData.comparing_to) }</p>
                </div>
              </Maybe>
            </div>
          </Tooltip>
      )
    })

    if (stats && query && query.period === 'realtime') {
      stats.push(this.blinkingDot())
    }

    return stats || null;
  }
}
