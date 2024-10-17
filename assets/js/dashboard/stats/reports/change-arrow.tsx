/** @format */

import React from 'react'
import { Metric } from '../../../types/query-api'
import { numberShortFormatter } from '../../util/number-formatter'
import {
  ArrowTrendingDownIcon,
  ArrowTrendingUpIcon
} from '@heroicons/react/20/solid'
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
  const magnitude = Math.abs(change)
  const formattedChange = hideNumber
    ? null
    : ` ${numberShortFormatter(magnitude)}%`

  const colorPositive = 'text-green-500'
  const colorNegative = 'text-red-400'
  const shouldReverseColors = metric === 'bounce_rate'
  const isBigChange = magnitude > 0.5

  const iconClass = classNames(
    'inline-block h-3 w-3',
    isBigChange && 'stroke-1 stroke-current'
  )

  return (
    <span className={className} data-testid="change-arrow">
      {change === 0 && <span className={iconClass}>&#12336;</span>}
      {change > 0 && (
        <ArrowTrendingUpIcon
          className={classNames(
            iconClass,
            !shouldReverseColors ? colorPositive : colorNegative
          )}
        />
      )}
      {change < 0 && (
        <ArrowTrendingDownIcon
          className={classNames(
            iconClass,
            !shouldReverseColors ? colorNegative : colorPositive
          )}
        />
      )}
      {formattedChange}
    </span>
  )
}
