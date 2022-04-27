import React from "react";
import numberFormatter, {durationFormatter} from '../../util/number-formatter'
import { METRIC_MAPPING, METRIC_LABELS } from './visitor-graph'

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
      return <span className="text-xs text-gray-700 dark:text-gray-300">&#12336; N/A</span>
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

  topStatTooltip(stat) {
    if (['visit duration', 'time on page', 'bounce rate', 'conversion rate'].includes(stat.name.toLowerCase())) {
      return null
    } else {
      let name = stat.name.toLowerCase()
      name = stat.value === 1 ? name.slice(0, -1) : name
      return stat.value.toLocaleString() + ' ' + name
    }
  }

  titleFor(stat) {
    if(this.props.metric === METRIC_MAPPING[stat.name]) {
      return `Hide ${METRIC_LABELS[METRIC_MAPPING[stat.name]].toLowerCase()} from graph`
    } else {
      return `Show ${METRIC_LABELS[METRIC_MAPPING[stat.name]].toLowerCase()} on graph`
    }
  }

  renderStat(stat) {
    return (
      <div className="flex items-center justify-between my-1 whitespace-nowrap">
        <b className="mr-4 text-xl md:text-2xl dark:text-gray-100" tooltip={this.topStatTooltip(stat)}>{this.topStatNumberShort(stat)}</b>
        {this.renderComparison(stat.name, stat.change)}
      </div>
    )
  }

  render() {
    const { updateMetric, metric, topStatData, query } = this.props

    const stats = topStatData && topStatData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-gray-300' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border
      const isClickable = Object.keys(METRIC_MAPPING).includes(stat.name) && !(query.filters.goal && stat.name === 'Unique visitors')
      const isSelected = metric === METRIC_MAPPING[stat.name]
      const [statDisplayName, statExtraName] = stat.name.split(/(\(.+\))/g)

      return (
        <React.Fragment key={stat.name}>
          { isClickable ?
            (
              <div className={`px-4 md:px-6 w-1/2 my-4 lg:w-auto group cursor-pointer select-none ${border}`} onClick={() => { updateMetric(METRIC_MAPPING[stat.name]) }} tabIndex={0} title={this.titleFor(stat)}>
                <div
                  className={`text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-content border-b ${isSelected ? 'text-indigo-700 dark:text-indigo-500 border-indigo-700 dark:border-indigo-500' : 'group-hover:text-indigo-700 dark:group-hover:text-indigo-500 border-transparent'}`}>
                  {statDisplayName}
                  {statExtraName && <span className="hidden sm:inline-block ml-1">{statExtraName}</span>}
                </div>
                { this.renderStat(stat) }
              </div>
            ) : (
              <div className={`px-4 md:px-6 w-1/2 my-4 lg:w-auto ${border}`}>
                <div className='text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex'>
                  {stat.name}
                </div>
                { this.renderStat(stat) }
              </div>
            )}
        </React.Fragment>
      )
    })

    if (query && query.period === 'realtime') {
      stats.push(<div key="dot" className="block pulsating-circle" style={{ left: '125px', top: '52px' }}></div>)
    }

    return stats
  }
}
