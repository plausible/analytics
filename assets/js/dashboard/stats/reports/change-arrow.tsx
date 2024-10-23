/** @format */

import React from 'react'
import { Metric } from '../../../types/query-api'
import { numberShortFormatter } from '../../util/number-formatter'
import {
  ArrowDownRightIcon,
  ArrowUpRightIcon
} from '@heroicons/react/24/solid'
import classNames from 'classnames'

export function ChangeArrow({
  change,
  metric,
  className,
  hideNumber
}: {
  change: number
  metric: Metric
  className: string
  hideNumber?: boolean
}) {
  const formattedChange = hideNumber
    ? null
    : ` ${numberShortFormatter(Math.abs(change))}%`

  let icon = null
  const arrowClassName = classNames(color(change, metric), strokeClass(change), "inline-block h-3 w-3 stroke-current")

  if (change > 0) {
    icon = (<ArrowUpRightIcon className={arrowClassName} />)
  } else if (change < 0) {
    icon = (<ArrowDownRightIcon className={arrowClassName} />)
  } else if (change === 0 && !hideNumber) {
    icon = (<>&#12336;</>)
  }

  return (
    <span className={className} data-testid="change-arrow">
      {icon}
      {formattedChange}
    </span>
  )
}

function color(change: number, metric: Metric) {
  const invert = metric === 'bounce_rate'

  return (change > 0) != invert ? 'text-green-500' : 'text-red-400'
}

function strokeClass(change: number) {
  if (Math.abs(change) < 5) {
    return "stroke-[0.5px]"
  } else if (Math.abs(change) < 25) {
    return "stroke-[1px]"
  } else {
    return "stroke-[2px]"
  }
}
