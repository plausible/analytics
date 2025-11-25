import React from 'react'
import { createRoot } from 'react-dom/client'
import dateFormatter from './date-formatter'
import { METRIC_LABELS, hasMultipleYears } from './graph-util'
import { MetricFormatterShort } from '../reports/metric-formatter'
import { ChangeArrow } from '../reports/change-arrow'
import { UIMode } from '../../theme-context'

const renderBucketLabel = function (
  query,
  graphData,
  label,
  comparison = false
) {
  let isPeriodFull = graphData.full_intervals?.[label]
  if (comparison) isPeriodFull = true

  const shouldShowYear = hasMultipleYears(graphData)

  const formattedLabel = dateFormatter({
    interval: graphData.interval,
    longForm: true,
    period: query.period,
    isPeriodFull,
    shouldShowYear
  })(label)

  if (query.period === 'realtime') {
    return dateFormatter({
      interval: graphData.interval,
      longForm: true,
      period: query.period,
      shouldShowYear
    })(label)
  }

  if (graphData.interval === 'hour' || graphData.interval == 'minute') {
    const date = dateFormatter({
      interval: 'day',
      longForm: true,
      period: query.period,
      shouldShowYear
    })(label)
    return `${date}, ${formattedLabel}`
  }

  return formattedLabel
}

const calculatePercentageDifference = function (oldValue, newValue) {
  if (oldValue == 0 && newValue > 0) {
    return 100
  } else if (oldValue == 0 && newValue == 0) {
    return 0
  } else {
    return Math.round(((newValue - oldValue) / oldValue) * 100)
  }
}

const buildTooltipData = function (query, graphData, metric, tooltipModel) {
  const data = tooltipModel.dataPoints.find(
    (dataPoint) => dataPoint.dataset.yAxisID == 'y'
  )
  const comparisonData = tooltipModel.dataPoints.find(
    (dataPoint) => dataPoint.dataset.yAxisID == 'yComparison'
  )

  const label =
    data &&
    renderBucketLabel(query, graphData, graphData.labels[data.dataIndex])
  const comparisonLabel =
    comparisonData &&
    renderBucketLabel(
      query,
      graphData,
      graphData.comparison_labels[comparisonData.dataIndex],
      true
    )

  const value = graphData.plot[data.dataIndex]

  const formatter = MetricFormatterShort[metric]
  const comparisonValue = graphData.comparison_plot?.[comparisonData.dataIndex]
  const comparisonDifference =
    label &&
    comparisonData &&
    calculatePercentageDifference(comparisonValue, value)

  const formattedValue = formatter(value)
  const formattedComparisonValue = comparisonData && formatter(comparisonValue)

  return {
    label,
    formattedValue,
    comparisonLabel,
    formattedComparisonValue,
    comparisonDifference
  }
}

let tooltipRoot

export default function GraphTooltip(graphData, metric, query, theme) {
  return (context) => {
    const tooltipModel = context.tooltip
    const offset = document
      .getElementById('main-graph-canvas')
      .getBoundingClientRect()
    let tooltipEl = document.getElementById('chartjs-tooltip-main')

    if (!tooltipEl) {
      tooltipEl = document.createElement('div')
      tooltipEl.id = 'chartjs-tooltip-main'
      tooltipEl.className = 'chartjs-tooltip'
      tooltipEl.style.display = 'none'
      tooltipEl.style.opacity = 0
      document.body.appendChild(tooltipEl)
      tooltipRoot = createRoot(tooltipEl)
    }

    const bgClass = theme.mode === UIMode.dark ? 'bg-gray-950' : 'bg-gray-800'
    tooltipEl.className = `absolute text-sm font-normal py-3 px-4 pointer-events-none rounded-md z-[100] min-w-[180px] ${bgClass}`

    if (tooltipEl && offset && window.innerWidth < 768) {
      tooltipEl.style.top =
        offset.y + offset.height + window.scrollY + 15 + 'px'
      tooltipEl.style.left = offset.x + 'px'
      tooltipEl.style.right = null
      tooltipEl.style.opacity = 1
    }

    if (tooltipModel.opacity === 0) {
      tooltipEl.style.display = 'none'
      return
    }

    if (tooltipModel.body) {
      const tooltipData = buildTooltipData(
        query,
        graphData,
        metric,
        tooltipModel
      )

      tooltipRoot.render(
        <aside className="text-gray-100 flex flex-col gap-1.5">
          <div className="flex justify-between items-center">
            <span className="font-semibold mr-4 text-xs uppercase">
              {METRIC_LABELS[metric]}
            </span>
            {tooltipData.comparisonDifference ? (
              <div className="inline-flex items-center space-x-1">
                <ChangeArrow
                  metric={metric}
                  change={tooltipData.comparisonDifference}
                />
              </div>
            ) : null}
          </div>

          {tooltipData.label ? (
            <div className="flex flex-col">
              <div className="flex flex-row justify-between items-center text-sm">
                <span className="flex items-center mr-4">
                  <div
                    className="size-2 mr-2 rounded-full"
                    style={{ backgroundColor: 'rgba(101,116,205)' }}
                  ></div>
                  <span>{tooltipData.label}</span>
                </span>
                <span className="font-bold">{tooltipData.formattedValue}</span>
              </div>

              {tooltipData.comparisonLabel ? (
                <div className="flex flex-row justify-between items-center text-sm">
                  <span className="flex items-center mr-4">
                    <div className="size-2 mr-2 rounded-full bg-gray-500"></div>
                    <span>{tooltipData.comparisonLabel}</span>
                  </span>
                  <span className="font-bold">
                    {tooltipData.formattedComparisonValue}
                  </span>
                </div>
              ) : null}
            </div>
          ) : null}

          {['month', 'day'].includes(graphData.interval) && (
            <>
              <hr className="border-gray-600 dark:border-gray-800 my-1" />
              <span className="text-gray-300 dark:text-gray-400 text-xs">
                Click to view {graphData.interval}
              </span>
            </>
          )}
        </aside>
      )
    }
    tooltipEl.style.display = null
  }
}
