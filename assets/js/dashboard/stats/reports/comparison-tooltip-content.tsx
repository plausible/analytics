import React, { Fragment } from 'react'
import { Metric } from '../../../types/query-api'
import numberShortFormatter from '../../util/number-formatter'

export function ComparisonTooltipContent({
}: {
  metric: Metric
  metricName: string,
  value: any,
  comparisonValue: any,
  formatter: (value: any) => any
}) {
  return <Fragment />
}


export function ChangeArrow({ change, metric, className, hideNumber }: { change: number, metric: Metric, className: string, hideNumber?: boolean }) {
  const formattedChange = hideNumber ? null : ` ${numberShortFormatter(Math.abs(change))}%`

  if (change > 0) {
    const color = metric === 'bounce_rate' ? 'text-red-400' : 'text-green-500'
    return (
      <span className={className}>
        <span className={color + ' font-bold'}>&uarr;</span>
        {formattedChange}
      </span>
    )
  } else if (change < 0) {
    const color = metric === 'bounce_rate' ? 'text-green-500' : 'text-red-400'
    return (
      <span className={className}>
        <span className={color + ' font-bold'}>&darr;</span>
        {formattedChange}
      </span>
    )
  } else if (change === 0) {
    return <span className={className}>&#12336;{formattedChange}</span>
  }
}
