import React, { useMemo } from 'react'
import { Metric } from '../../../types/query-api'
import { Tooltip } from '../../util/tooltip'
import { ChangeArrow } from './comparison-tooltip-content'

type MetricValues = Record<Metric, number | null>

type ListItem =
  MetricValues
  & {
    comparison: MetricValues & { change: Record<Metric, number> }
  }

function valueRenderProps(listItem: ListItem, metric: Metric) {
  const value = listItem[metric]

  let comparison = null
  if (listItem.comparison) {
    comparison = {
      value: listItem.comparison[metric],
      change: listItem.comparison.change[metric]
    }
  }

  return { value, comparison }
}

export default function MetricEntry({ listItem, metric, formatter }: { listItem: ListItem, metric: Metric, formatter: (value: number | null) => any }) {
  const { value, comparison } = useMemo(() => valueRenderProps(listItem, metric), [listItem, metric])

  const tooltipBoundary = React.useRef(null)

  return (
    <div ref={tooltipBoundary}>
      <Tooltip
        info={
          comparison ? (
            <div className="whitespace-nowrap">
              {formatter(value)} vs {formatter(comparison.value)}, Change: {comparison.change}%
            </div>
          )
            : formatter(value)
        }
      >
        {formatter(value)}
        {comparison ? <ChangeArrow change={comparison.change} metric={metric} className="pl-2 text-xs text-gray-100" /> : null}
      </Tooltip>
    </div>
  )
}
