import React, { ReactNode, useMemo } from 'react'
import { Metric } from '../../../types/query-api'
import { Tooltip } from '../../util/tooltip'
import { ChangeArrow } from './comparison-tooltip-content'
import { MetricFormatterLong, MetricFormatterShort } from './metric-formatter'
import { DashboardQuery } from '../../query'
import { useQueryContext } from '../../query-context'

type MetricValues = Record<Metric, any>

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

export default function MetricEntry(props: {
  listItem: ListItem,
  metric: Metric,
  renderLabel: (query: DashboardQuery) => string,
  formatter?: (value: any) => any
}) {
  const { query } = useQueryContext()

  const {metric, listItem} = props
  const {value, comparison} = useMemo(() => valueRenderProps(listItem, metric), [listItem, metric])
  const metricLabel = useMemo(() => props.renderLabel(query), [query])
  const shortFormatter = props.formatter ?? MetricFormatterShort[metric]

  if (value === null && (!comparison || comparison.value === null)) {
    return <>{shortFormatter(value)}</>
  }

  return (
    <Tooltip
      info={<ComparisonTooltipContent value={value} comparison={comparison} metricLabel={metricLabel} {...props} />}
    >
      {shortFormatter(value)}
      {comparison ? <ChangeArrow change={comparison.change} metric={metric} className="pl-2" hideNumber /> : null}
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
  value: any,
  comparison: { value: any, change: number } | null,
  metric: Metric,
  metricLabel: string,
  formatter?: (value: any) => any
}) {
  const longFormatter = formatter ?? MetricFormatterLong[metric]

  const label = useMemo(() => {
    if (metricLabel.length < 3) {
      return ""
    }
    let label = metricLabel.toLowerCase()
    label = value === 1 ? label.slice(0, -1) : label

    return ` ${label}`
  }, [metricLabel])

  if (!comparison) {
    return (
      <div className="whitespace-nowrap">
        {longFormatter(value)}
      </div>
    )
  }

  return (
    <div className="whitespace-nowrap">
      {longFormatter(value)} vs. {longFormatter(comparison.value)}{label}
      <ChangeArrow metric={metric} change={comparison.change} className="pl-4 text-xs text-gray-100" />
    </div>
  )
}
