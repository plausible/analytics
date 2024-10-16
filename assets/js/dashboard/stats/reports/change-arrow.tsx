import React from 'react'
import { Metric } from '../../../types/query-api'
import { numberShortFormatter } from '../../util/number-formatter'

export function ChangeArrow({ change, metric, className, hideNumber }: { change: number, metric: Metric, className: string, hideNumber?: boolean }) {
  const formattedChange = hideNumber ? null : `${numberShortFormatter(Math.abs(change))}%`

  let content = null

  if (change > 0) {
    const color = metric === 'bounce_rate' ? 'text-red-400' : 'text-green-500'
    content = (
      <>
        <span className={color + ' font-bold'}>&uarr;</span>
        {formattedChange}
      </>
    )
  } else if (change < 0) {
    const color = metric === 'bounce_rate' ? 'text-green-500' : 'text-red-400'
    content = (
      <>
        <span className={color + ' font-bold'}>&darr;</span>
        {formattedChange}
      </>
    )
  } else if (change === 0) {
    content = <>&#12336;{formattedChange}</>
  }

  return <span className={className} data-testid="change-arrow">{content}</span>
}
