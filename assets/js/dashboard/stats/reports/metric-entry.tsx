import React from 'react'
import { Metric } from '../../../types/query-api'

type MetricValues = Record<Metric, number | null>

type ListItem =
  MetricValues
  & {
    comparison: MetricValues & { change: MetricValues }
  }

function valueRenderProps(listItem: ListItem, metricName: Metric) {
  const value = listItem[metricName]

  let comparison = null
  if (listItem.comparison) {
    comparison = {
      value: listItem.comparison[metricName],
      change: listItem.comparison.change[metricName]
    }
  }

  return { value, comparison }
}

export default function MetricEntry({ listItem, metricName, formatter }: { listItem: ListItem, metricName: Metric, formatter: (value: number | null) => any}) {
  const { value, comparison } = valueRenderProps(listItem, metricName)
  let tooltip = formatter(value)

  let arrow = null
  if (comparison) {
    tooltip = `Previous: ${formatter(comparison.value)}, Change: ${comparison.change}%`

    arrow = <ChangeArrow change={comparison.change} metricName={metricName} />
  }
  return <span tooltip={tooltip}>{formatter(value)}{arrow}</span>
}

function ChangeArrow({ change, metricName }: { change: number | null, metricName: string }) {
  if (change === null) {
    return null
  } else if (change > 0) {
    const color = metricName === 'bounce_rate' ? 'text-red-400' : 'text-green-500'
    return (
      <span className="pl-2">
        <span className={color + ' font-bold'}>&uarr;</span>{' '}
      </span>
    )
  } else if (change < 0) {
    const color = metricName === 'bounce_rate' ? 'text-green-500' : 'text-red-400'
    return (
      <span className="pl-2">
        <span className={color + ' font-bold'}>&darr;</span>{' '}
      </span>
    )
  } else if (change === 0) {
    return <span className="pl-2">&#12336;</span>
  }
}
