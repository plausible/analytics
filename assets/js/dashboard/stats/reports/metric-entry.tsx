import React, { useMemo } from 'react'
import { Metric } from '../../../types/query-api'
import { Tooltip } from '../../util/tooltip'

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
  const { value, comparison } = useMemo(() => valueRenderProps(listItem, metricName), [listItem, metricName])

  const tooltipBoundary = React.useRef(null)

  return (
    <div ref={tooltipBoundary}>
      <Tooltip
        info={
          comparison ? `Previous: ${formatter(comparison.value)}, Change: ${comparison.change}%` : formatter(value)
        }
      >
        {formatter(value)}
        {comparison ? <ChangeArrow change={comparison.change} metricName={metricName} /> : null}
      </Tooltip>
    </div>
  )
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
