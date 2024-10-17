/** @format */

import React, { useMemo } from 'react'
import { Metric } from '../../../types/query-api'
import { Tooltip } from '../../util/tooltip'
import { ChangeArrow } from './change-arrow'
import {
  MetricFormatterLong,
  MetricFormatterShort,
  ValueType
} from './metric-formatter'
import { DashboardQuery } from '../../query'
import { useQueryContext } from '../../query-context'

type MetricValues = Record<Metric, ValueType>

type ListItem = MetricValues & {
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

export default function MetricValue(props: {
  listItem: ListItem
  metric: Metric
  renderLabel: (query: DashboardQuery) => string
  formatter?: (value: ValueType) => string
}) {
  const { query } = useQueryContext()

  const { metric, listItem } = props
  const { value, comparison } = useMemo(
    () => valueRenderProps(listItem, metric),
    [listItem, metric]
  )
  const metricLabel = useMemo(() => props.renderLabel(query), [query, props])
  const shortFormatter = props.formatter ?? MetricFormatterShort[metric]

  if (value === null && (!comparison || comparison.value === null)) {
    return <span data-testid="metric-value">{shortFormatter(value)}</span>
  }

  return (
    <Tooltip
      info={
        <ComparisonTooltipContent
          value={value}
          comparison={comparison}
          metricLabel={metricLabel}
          {...props}
        />
      }
    >
      <span data-testid="metric-value">
        {shortFormatter(value)}
        {comparison ? (
          <ChangeArrow
            change={comparison.change}
            metric={metric}
            className="pl-2"
            hideNumber
          />
        ) : null}
      </span>
    </Tooltip>
  )
}

function ComparisonTooltipContent({
  value,
  comparison,
  metric,
  metricLabel,
  formatter
}: {
  value: ValueType
  comparison: { value: ValueType; change: number } | null
  metric: Metric
  metricLabel: string
  formatter?: (value: ValueType) => string
}) {
  const longFormatter = formatter ?? MetricFormatterLong[metric]

  const label = useMemo(() => {
    if (metricLabel.length < 3) {
      return ''
    }

    return ` ${metricLabel.toLowerCase()}`
  }, [metricLabel])

  if (comparison) {
    return (
      <div className="whitespace-nowrap">
        {longFormatter(value)} vs. {longFormatter(comparison.value)}
        {label}
        <ChangeArrow
          metric={metric}
          change={comparison.change}
          className="pl-4 text-xs text-gray-100"
        />
      </div>
    )
  } else {
    return <div className="whitespace-nowrap">{longFormatter(value)}</div>
  }
}
