import React from "react";
import { Tooltip } from '../../util/tooltip'
import { SecondsSinceLastLoad } from '../../util/seconds-since-last-load'
import classNames from "classnames";
import numberFormatter, { durationFormatter } from '../../util/number-formatter'
import { METRIC_MAPPING } from './graph-util'

export default class TopStats extends React.Component {
  renderComparison(name, comparison) {
    const formattedComparison = numberFormatter(Math.abs(comparison))

    if (comparison > 0) {
      const color = name === 'Bounce rate' ? 'text-red-400' : 'text-green-500'
      return <span className="text-xs dark:text-gray-100"><span className={color + ' font-bold'}>&uarr;</span> {formattedComparison}%</span>
    } else if (comparison < 0) {
      const color = name === 'Bounce rate' ? 'text-green-500' : 'text-red-400'
      return <span className="text-xs dark:text-gray-100"><span className={color + ' font-bold'}>&darr;</span> {formattedComparison}%</span>
    } else if (comparison === 0) {
      return <span className="text-xs text-gray-700 dark:text-gray-300">&#12336; 0%</span>
    }
  }

  topStatNumberShort(stat) {
    if (['visit duration', 'time on page'].includes(stat.name.toLowerCase())) {
      return durationFormatter(stat.value)
    } else if (['bounce rate', 'conversion rate'].includes(stat.name.toLowerCase())) {
      return stat.value + '%'
    } else {
      return numberFormatter(stat.value)
    }
  }

  topStatNumberLong(stat) {
    if (['visit duration', 'time on page'].includes(stat.name.toLowerCase())) {
      return durationFormatter(stat.value)
    } else if (['bounce rate', 'conversion rate'].includes(stat.name.toLowerCase())) {
      return stat.value + '%'
    } else {
      return stat.value.toLocaleString()
    }
  }

  topStatTooltip(stat) {
    let statName = stat.name.toLowerCase()
    statName = stat.value === 1 ? statName.slice(0, -1) : statName

    return (
      <div>
        <div className="whitespace-nowrap">{this.topStatNumberLong(stat)} {statName}</div>
        {this.canMetricBeGraphed(stat) && <div className="font-normal text-xs">{this.titleFor(stat)}</div>}
        {stat.name === 'Current visitors' && <p className="font-normal text-xs">Last updated <SecondsSinceLastLoad lastLoadTimestamp={this.props.lastLoadTimestamp}/>s ago</p>}
      </div>
    )
  }

  titleFor(stat) {
    const isClickable = this.canMetricBeGraphed(stat)

    if (isClickable && this.props.metric === METRIC_MAPPING[stat.name]) {
      return "Click to hide"
    } else if (isClickable) {
      return "Click to show"
    } else {
      return null
    }
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
    const { topStatData, query } = this.props

    const stats = topStatData && topStatData.top_stats.map((stat, index) => {

      const className = classNames('px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none', {
        'cursor-pointer': this.canMetricBeGraphed(stat),
        'lg:border-l border-gray-300': index > 0,
        'border-r lg:border-r-0': index % 2 === 0
      })

      return (
          <Tooltip key={stat.name} info={this.topStatTooltip(stat)} className={className} onClick={() => { this.maybeUpdateMetric(stat) }} boundary={this.props.tooltipBoundary}>
            {this.renderStatName(stat)}
            <div className="flex items-center justify-between my-1 whitespace-nowrap">
              <b className="mr-4 text-xl md:text-2xl dark:text-gray-100" id={METRIC_MAPPING[stat.name]}>{this.topStatNumberShort(stat)}</b>
              {this.renderComparison(stat.name, stat.change)}
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
