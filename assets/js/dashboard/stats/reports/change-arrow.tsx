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

  let content = null

  if (change > 0) {
    const color = metric === 'bounce_rate' ? 'text-red-400' : 'text-green-500'
    content = (
      <>
        <ArrowUpRightIcon className={classNames(color, "inline-block h-3 w-3 stroke-[1.5px] stroke-current")} />
        {formattedChange}
      </>
    )
  } else if (change < 0) {
    const color = metric === 'bounce_rate' ? 'text-green-500' : 'text-red-400'
    content = (
      <>
        <ArrowDownRightIcon className={classNames(color, "inline-block h-3 w-3 stroke-[1.5px] stroke-current")} />
        {formattedChange}
      </>
    )
  } else if (change === 0) {
    content = <>&#12336;{formattedChange}</>
  }

  return (
    <span className={className} data-testid="change-arrow">
      {content}
    </span>
  )
}
