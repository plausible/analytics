import React, { useMemo, useRef, useEffect } from 'react'
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
  meta: BreakdownResultMeta | null
  detailedView?: boolean
  isRowHovered?: boolean
}) {
  const { query } = useQueryContext()
  const portalRef = useRef<HTMLElement | null>(null)

  useEffect(() => {
    if (typeof document !== 'undefined') {
      portalRef.current = document.body
    }
  }, [])

  const { metric, listItem, detailedView = false, isRowHovered = false } = props
  const { value, comparison } = useMemo(
    () => valueRenderProps(listItem, metric),
    [listItem, metric]
  )
  const metricLabel = useMemo(() => props.renderLabel(query), [query, props])
  const shortFormatter = props.formatter ?? MetricFormatterShort[metric]
  const longFormatter = props.formatter ?? MetricFormatterLong[metric]

  const isAbbreviated = useMemo(() => {
    if (value === null) return false
    return shortFormatter(value) !== longFormatter(value)
  }, [value, shortFormatter, longFormatter])

  const showTooltip = detailedView
    ? !!comparison
    : !!comparison || isAbbreviated

  const shouldShowLongFormat =
    detailedView && !comparison && isRowHovered && isAbbreviated
  const displayFormatter = shouldShowLongFormat ? longFormatter : shortFormatter

  const percentageValue = listItem['percentage' as Metric]
  const shouldShowPercentage =
    detailedView &&
    metric === 'visitors' &&
    isRowHovered &&
    percentageValue != null
  const percentageFormatter = MetricFormatterShort['percentage']
  const percentageDisplay = shouldShowPercentage
    ? percentageFormatter(percentageValue)
    : null

  if (value === null && (!comparison || comparison.value === null)) {
    return <span data-testid="metric-value">{displayFormatter(value)}</span>
  }

  const valueContent = (
    <span
      className={showTooltip ? 'cursor-default' : ''}
      data-testid="metric-value"
    >
      {percentageDisplay && (
        <span className="mr-3 text-gray-500 dark:text-gray-400">
          {percentageDisplay}
        </span>
      )}
      {displayFormatter(value)}
      {comparison ? (
        <ChangeArrow
          change={comparison.change}
          metric={metric}
          className="inline-block pl-1 w-4"
          hideNumber
        />
      ) : null}
    </span>
  )

  if (!showTooltip) {
    return valueContent
  }

  return (
    <Tooltip
      containerRef={portalRef as React.RefObject<HTMLElement>}
      info={
        <ComparisonTooltipContent
          value={value}
          comparison={comparison}
          metricLabel={metricLabel}
          {...props}
        />
      }
    >
      {valueContent}
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
  formatter?: (value: ValueType) => string
  meta: BreakdownResultMeta | null
}) {
  const longFormatter = formatter ?? MetricFormatterLong[metric]

  const label = useMemo(() => {
    if (metricLabel.length < 3) {
      return ''
    }

    return ` ${metricLabel.toLowerCase()}`
  }, [metricLabel])

  if (comparison && meta) {
    return (
      <div className="text-left whitespace-nowrap py-1 space-y-2">
        <div>
          <div className="flex gap-x-4">
            <div className="flex flex-col">
              <span className="font-medium text-sm/6 text-white">
                {longFormatter(value)} {label}
              </span>
              <div className="font-normal text-xs text-white">
                {meta.date_range_label}
              </div>
            </div>
            <ChangeArrow
              metric={metric}
              change={comparison.change}
              className="text-xs/6 font-medium text-white"
            />
          </div>
        </div>
        <div className="w-full border-t border-gray-600"></div>
        <div>
          <div className="font-medium text-sm/6 text-gray-300/80">
            {longFormatter(comparison.value)} {label}
          </div>
          <div className="font-normal text-xs text-gray-300/80">
            {meta.comparison_date_range_label}
          </div>
        </div>
      </div>
    )
  } else {
    return <div className="whitespace-nowrap">{longFormatter(value)}</div>
  }
}
