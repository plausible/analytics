import React from 'react'
import { Metric } from '../../../types/query-api'
import { numberShortFormatter } from '../../util/number-formatter'
import { ArrowDownRightIcon, ArrowUpRightIcon } from '@heroicons/react/24/solid'
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
  let icon = null
  const arrowClassName = classNames(
    color(change, metric),
    'mb-0.5 inline-block size-3 stroke-[1px] stroke-current'
  )

  if (change > 0) {
    icon = <ArrowUpRightIcon className={arrowClassName} />
  } else if (change < 0) {
    icon = <ArrowDownRightIcon className={arrowClassName} />
  }

  const formattedChange = hideNumber
    ? null
    : `${icon ? ' ' : ''}${numberShortFormatter(Math.abs(change))}%`

  return (
    <span className={className} data-testid="change-arrow">
      {icon}
      {formattedChange}
    </span>
  )
}

function color(change: number, metric: Metric) {
  const invert = metric === 'bounce_rate'

  return change > 0 != invert ? 'text-green-500' : 'text-red-400'
}
