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
import { BreakdownResultMeta, DashboardQuery } from '../../query'
import { useQueryContext } from '../../query-context'
import { PlausibleSite, useSiteContext } from '../../site-context'

type MetricValues = Record<Metric, ValueType>

type ListItem = MetricValues & {
  comparison: MetricValues & { change: Record<Metric, number> }
}

function valueRenderProps(
  listItem: ListItem,
  metric: Metric,
  site: PlausibleSite
) {
  const value = listItem[metric]

  let comparison = null
  if (site.flags.breakdown_comparisons_ui && listItem.comparison) {
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
  formatter?: (value: ValueType) => string,
  meta?: BreakdownResultMeta
}) {
  const { query } = useQueryContext()
  const site = useSiteContext()

  const { metric, listItem } = props
  const { value, comparison } = useMemo(
    () => valueRenderProps(listItem, metric, site),
    [listItem, metric, site]
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
      <span className="cursor-default" data-testid="metric-value">
        {shortFormatter(value)}
        {comparison && comparison.change === 0 ? (
          <span className="inline-block w-4"></span>
        ) : null}
        {comparison && comparison.change !== 0 ? (
          <ChangeArrow
            change={comparison.change}
            metric={metric}
            className="inline-block pl-2 w-4"
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
  formatter,
  meta
}: {
  value: ValueType
  comparison: { value: ValueType; change: number } | null
  metric: Metric
  metricLabel: string
  formatter?: (value: ValueType) => string,
  meta?: BreakdownResultMeta
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
      <div className="text-left whitespace-nowrap py-1 space-y-2">
        <div>
          <div className="flex items-center">
            <span className="font-bold text-base">{longFormatter(value)} {label}</span>
            <ChangeArrow
              metric={metric}
              change={comparison.change}
              className="pl-4 text-xs text-gray-100"
            />
          </div>
          <div className="font-normal text-xs">{meta?.date_range}</div>
        </div>
        <div>vs</div>
        <div>
          <div className="font-bold text-base">{longFormatter(comparison.value)} {label}</div>
          <div className="font-normal text-xs">{meta?.comparison_date_range}</div>
        </div>
      </div>
    )
  } else {
    return <div className="whitespace-nowrap">{longFormatter(value)} {label}</div>
  }
}
