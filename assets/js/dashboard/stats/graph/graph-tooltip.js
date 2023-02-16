import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server';
import { METRIC_FORMATTER, METRIC_LABELS } from './graph-util.js'
import dateFormatter from './date-formatter.js'

const renderBucketLabel = function(query, graphData, label, comparison = false) {
  let isPeriodFull = graphData.full_intervals?.[label]
  if (comparison) isPeriodFull = true

  const formattedLabel = dateFormatter({
    interval: graphData.interval, longForm: true, period: query.period, isPeriodFull,
  })(label)

  if (query.period === 'realtime') {
    return dateFormatter({
      interval: graphData.interval, longForm: true, period: query.period,
    })(label)
  }

  if (graphData.interval === 'hour' || graphData.interval == 'minute') {
    const date = dateFormatter({ interval: "date", longForm: true, period: query.period })(label)
    return `${date}, ${formattedLabel}`
  }

  return formattedLabel
}

const calculatePercentageDifference = function(oldValue, newValue) {
  if (oldValue == 0 && newValue > 0) {
    return 100
  } else if (oldValue == 0 && newValue == 0) {
    return 0
  } else {
    return Math.round((newValue - oldValue) / oldValue * 100)
  }
}

const buildTooltipData = function(query, graphData, metric, tooltipModel) {
  const data = tooltipModel.dataPoints.find((dataPoint) => dataPoint.dataset.yAxisID == "y")
  const comparisonData = tooltipModel.dataPoints.find((dataPoint) => dataPoint.dataset.yAxisID == "yComparison")

  const label = renderBucketLabel(query, graphData, graphData.labels[data.dataIndex])
  const comparisonLabel = comparisonData && renderBucketLabel(query, graphData, graphData.comparison_labels[data.dataIndex], true)

  const value = data?.raw || 0
  const comparisonValue = comparisonData?.raw || 0
  const comparisonDifference = comparisonData && calculatePercentageDifference(comparisonValue, value)

  const metricFormatter = METRIC_FORMATTER[metric]
  const formattedValue = metricFormatter(value)
  const formattedComparisonValue = comparisonData && metricFormatter(comparisonValue)

  return { label, formattedValue, comparisonLabel, formattedComparisonValue, comparisonDifference }
}

export default function GraphTooltip(graphData, metric, query) {
  return (context) => {
    const tooltipModel = context.tooltip;
    const offset = document.getElementById("main-graph-canvas").getBoundingClientRect()

    // Tooltip Element
    let tooltipEl = document.getElementById('chartjs-tooltip');

    // Create element on first render
    if (!tooltipEl) {
      tooltipEl = document.createElement('div');
      tooltipEl.id = 'chartjs-tooltip';
      tooltipEl.style.display = 'none';
      tooltipEl.style.opacity = 0;
      document.body.appendChild(tooltipEl);
    }

    if (tooltipEl && offset && window.innerWidth < 768) {
      tooltipEl.style.top = offset.y + offset.height + window.scrollY + 15 + 'px'
      tooltipEl.style.left = offset.x + 'px'
      tooltipEl.style.right = null;
      tooltipEl.style.opacity = 1;
    }

    // Stop if no tooltip showing
    if (tooltipModel.opacity === 0) {
      tooltipEl.style.display = 'none';
      return;
    }

    // Set Tooltip Body
    if (tooltipModel.body) {
      const tooltipData = buildTooltipData(query, graphData, metric, tooltipModel)

      let innerHtml = (
        <div className="text-gray-100 flex flex-col">
          <div className="flex justify-between items-center">
            <span className="font-semibold mr-4 text-lg">{METRIC_LABELS[metric]}</span>
            {tooltipData.comparisonDifference && <span className="font-semibold text-sm" >{tooltipData.comparisonDifference}%</span>}
          </div>
          <div className="flex flex-col">
            <div className="flex flex-row justify-between items-center">
              <span className="flex items-center mr-4">
                <div className="w-3 h-3 mr-1 rounded-full" style={{backgroundColor: "rgba(101,116,205)"}}></div>
                <span>{tooltipData.label}</span>
              </span>
              <span className="text-base font-bold">{tooltipData.formattedValue}</span>
            </div>

            {tooltipData.comparisonLabel &&
            <div className="flex flex-row justify-between items-center">
              <span className="flex items-center mr-4">
                <div className="w-3 h-3 mr-1 rounded-full bg-gray-500"></div>
                <span>{tooltipData.comparisonLabel}</span>
              </span>
              <span className="text-base font-bold">{tooltipData.formattedComparisonValue}</span>
            </div>}

            <span className="font-semibold italic">{graphData.interval === 'month' ? 'Click to view month' : graphData.interval === 'date' ? 'Click to view day' : ''}</span>
          </div>
        </div>
      )

      tooltipEl.innerHTML = renderToStaticMarkup(innerHtml)
    }
    tooltipEl.style.display = null;
  }
}
