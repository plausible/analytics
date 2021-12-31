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

  render() {
    const { updateMetric, metric, topStatData, query } = this.props

		console.log(topStatData.top_stats, METRIC_MAPPING)

    const stats = topStatData && topStatData.top_stats.map((stat, index) => {
      let border = index > 0 ? 'lg:border-l border-gray-300' : ''
      border = index % 2 === 0 ? border + ' border-r lg:border-r-0' : border

      return (
        <div className={`px-4 md:px-6 w-1/2 my-4 lg:w-auto ${border}`} key={stat.name}>
          {Object.keys(METRIC_MAPPING).includes(stat.name) && !(query.filters.goal && stat.name === 'Unique visitors') ?
            (
              <div
                className={`text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap cursor-pointer flex w-content border-b-2 ${metric === METRIC_MAPPING[stat.name] ? 'text-indigo-700 dark:text-indigo-500 border-indigo-700 dark:border-indigo-500' : 'hover:text-indigo-600 dark:hover:text-indigo-600 cursor-pointer border-transparent'}`}
                title={metric === METRIC_MAPPING[stat.name] ?
                  `Hide ${METRIC_LABELS[METRIC_MAPPING[stat.name]].toLowerCase()} from graph` :
                  `Show ${METRIC_LABELS[METRIC_MAPPING[stat.name]].toLowerCase()} on graph`
                }
                onClick={() => { updateMetric(METRIC_MAPPING[stat.name]) }}
                tabIndex={0}
              >
                {stat.name.split('(')[0]}
                {stat.name.split('(').length > 1 ? (<span className="hidden sm:inline-block ml-1"> {"(" + stat.name.split('(')[1]}</span>) : null}
              </div>
            ) : (
              <div className='text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex'>
                {stat.name}
              </div>
            )}
          <div className="flex items-center justify-between my-1 whitespace-nowrap">
            <b className="mr-4 text-xl md:text-2xl dark:text-gray-100" tooltip={this.topStatTooltip(stat)}>{this.topStatNumberShort(stat)}</b>
            {this.renderComparison(stat.name, stat.change)}
          </div>
        </div>
      )
    })

    if (query && query.period === 'realtime') {
      stats.push(<div key="dot" className="block pulsating-circle" style={{ left: '125px', top: '52px' }}></div>)
    }

    if (topStatData && topStatData.sample_percent < 100) {
      stats.push(
        <div tooltip={`Stats based on a ${topStatData.sample_percent}% sample of all visitors`} className="cursor-pointer mr-8 ml-auto my-auto">
          <svg className="w-4 h-4 text-gray-300 dark:text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>)
    }

    return stats
  }
}
