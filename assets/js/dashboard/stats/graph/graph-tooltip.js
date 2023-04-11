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

  const label = data && renderBucketLabel(query, graphData, graphData.labels[data.dataIndex])
  const comparisonLabel = comparisonData && renderBucketLabel(query, graphData, graphData.comparison_labels[comparisonData.dataIndex], true)

  const value = data?.raw || 0
  const comparisonValue = comparisonData?.raw || 0
  const comparisonDifference = label && comparisonLabel && calculatePercentageDifference(comparisonValue, value)

  const metricFormatter = METRIC_FORMATTER[metric]
  const formattedValue = metricFormatter(value)
  const formattedComparisonValue = comparisonData && metricFormatter(comparisonValue)

  return { label, formattedValue, comparisonLabel, formattedComparisonValue, comparisonDifference }
}

export default function GraphTooltip(graphData, metric, query) {
  return (context) => {
    const tooltipModel = context.tooltip
    const offset = document.getElementById("main-graph-canvas").getBoundingClientRect()
    let tooltipEl = document.getElementById('chartjs-tooltip')

    if (!tooltipEl) {
      tooltipEl = document.createElement('div')
      tooltipEl.id = 'chartjs-tooltip'
      tooltipEl.style.display = 'none'
      tooltipEl.style.opacity = 0
      document.body.appendChild(tooltipEl)
    }

    if (tooltipEl && offset && window.innerWidth < 768) {
      tooltipEl.style.top = offset.y + offset.height + window.scrollY + 15 + 'px'
      tooltipEl.style.left = offset.x + 'px'
      tooltipEl.style.right = null
      tooltipEl.style.opacity = 1
    }

    if (tooltipModel.opacity === 0) {
      tooltipEl.style.display = 'none'
      return
    }

    if (tooltipModel.body) {
      const tooltipData = buildTooltipData(query, graphData, metric, tooltipModel)

      tooltipEl.innerHTML = `
        <aside class="text-gray-100 flex flex-col">
          <div class="flex justify-between items-center">
            <span class="font-semibold mr-4 text-lg">${METRIC_LABELS[metric]}</span>
            ${tooltipData.comparisonDifference ?
            `<div class="inline-flex items-center space-x-1">
              ${tooltipData.comparisonDifference > 0 ? `<span class="font-semibold text-sm text-green-500">&uarr;</span><span>${tooltipData.comparisonDifference}%</span>` : ""}
              ${tooltipData.comparisonDifference < 0 ? `<span class="font-semibold text-sm text-red-400">&darr;</span><span>${tooltipData.comparisonDifference * -1}%</span>` : ""}
              ${tooltipData.comparisonDifference == 0 ? `<span class="font-semibold text-sm">〰 0%</span>` : ""}
            </div>` : ''}
          </div>

          ${tooltipData.label ?
          `<div class="flex flex-col">
            <div class="flex flex-row justify-between items-center">
              <span class="flex items-center mr-4">
                <div class="w-3 h-3 mr-1 rounded-full" style="background-color: rgba(101,116,205)"></div>
                <span>${tooltipData.label}</span>
              </span>
              <span class="text-base font-bold">${tooltipData.formattedValue}</span>
            </div>` : ''}

            ${tooltipData.comparisonLabel ?
            `<div class="flex flex-row justify-between items-center">
              <span class="flex items-center mr-4">
                <div class="w-3 h-3 mr-1 rounded-full bg-gray-500"></div>
                <span>${tooltipData.comparisonLabel}</span>
              </span>
              <span class="text-base font-bold">${tooltipData.formattedComparisonValue}</span>
            </div>` : ""}
          </div>

          ${graphData.interval === "month" ? `<span class="font-semibold italic">Click to view month</span>` : ""}
          ${graphData.interval === "date" ? `<span class="font-semibold italic">Click to view day</span>` : ""}
        </aside>
      `
    }
    tooltipEl.style.display = null
  }
}
