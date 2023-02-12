import numberFormatter, {durationFormatter} from '../../util/number-formatter'
import dateFormatter from './date-formatter.js'

export const METRIC_MAPPING = {
  'Unique visitors (last 30 min)': 'visitors',
  'Pageviews (last 30 min)': 'pageviews',
  'Unique visitors': 'visitors',
  'Visit duration': 'visit_duration',
  'Total pageviews': 'pageviews',
  'Bounce rate': 'bounce_rate',
  'Unique conversions': 'conversions',
}

export const METRIC_LABELS = {
  'visitors': 'Visitors',
  'pageviews': 'Pageviews',
  'bounce_rate': 'Bounce Rate',
  'visit_duration': 'Visit Duration',
  'conversions': 'Converted Visitors',
}

export const METRIC_FORMATTER = {
  'visitors': numberFormatter,
  'pageviews': numberFormatter,
  'bounce_rate': (number) => (`${number}%`),
  'visit_duration': durationFormatter,
  'conversions': numberFormatter,
}

export const LoadingState = {
  loading: 'loading',
  refreshing: 'refreshing',
  loaded: 'loaded',
  isLoadingOrRefreshing: function (state) { return [this.loading, this.refreshing].includes(state) },
  isLoadedOrRefreshing: function (state) { return [this.loaded, this.refreshing].includes(state) }
}

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

export const GraphTooltip = (graphData, metric, query) => {
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

      let innerHtml = `
      <div class='text-gray-100 flex flex-col'>
        <div class='flex justify-between items-center'>
          <span class='font-semibold mr-4 text-lg'>${METRIC_LABELS[metric]}</span>
          ${tooltipData.comparisonDifference ? `<span class='font-semibold text-sm'>${tooltipData.comparisonDifference}%</span>` : ''}
        </div>
        <div class='flex flex-col'>
          <div class='flex flex-row justify-between items-center'>
            <span class='flex items-center mr-4'>
              <div class='w-3 h-3 mr-1 rounded-full' style='background-color: rgba(101,116,205)'></div>
              <span>${tooltipData.label}</span>
            </span>
            <span class='text-base font-bold'>${tooltipData.formattedValue}</span>
          </div>

          ${tooltipData.comparisonLabel ? `<div class='flex flex-row justify-between items-center'>
            <span class='flex items-center mr-4'>
              <div class='w-3 h-3 mr-1 rounded-full bg-gray-500'></div>
              <span>${tooltipData.comparisonLabel}</span>
            </span>
            <span class='text-base font-bold'>${tooltipData.formattedComparisonValue}</span>
          </div>
        </div>
        <span class='font-semibold italic'>${graphData.interval === 'month' ? 'Click to view month' : graphData.interval === 'date' ? 'Click to view day' : ''}</span>
      </div>` : ''}
      `;

      tooltipEl.innerHTML = innerHtml;
    }
    tooltipEl.style.display = null;
  }
}

const truncateToPresentIndex = function(array, presentIndex) {
  return array.slice(0, presentIndex)
}

export const buildDataSet = (plot, comparisonPlot, present_index, ctx, label) => {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  var prev_gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');
  prev_gradient.addColorStop(0, 'rgba(101,116,205, 0.075)');
  prev_gradient.addColorStop(1, 'rgba(101,116,205, 0)');

  let comparisonDataSet = []
  if (comparisonPlot) {
    comparisonDataSet = [
      {
        label,
        data: truncateToPresentIndex(comparisonPlot, present_index),
        borderWidth: 3,
        borderColor: 'rgba(60,70,110,0.2)',
        pointBackgroundColor: 'rgba(60,70,110,0.2)',
        pointHoverBackgroundColor: 'rgba(60, 70, 110)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
        fill: true,
        yAxisID: 'yComparison',
      }
    ]
  }

  if (present_index) {
    var dashedPart = plot.slice(present_index - 1, present_index + 1);
    var dashedPlot = (new Array(present_index - 1)).concat(dashedPart)
    const _plot = truncateToPresentIndex([...plot], present_index)

    return [
      {
        label,
        data: _plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointBackgroundColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
        fill: true,
        yAxisID: 'y',
      },
      {
        label,
        data: dashedPlot,
        borderWidth: 3,
        borderDash: [3, 3],
        borderColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
        fill: true,
        yAxisID: 'y',
      }
    ].concat(comparisonDataSet)
  } else {
    return [
      {
        label,
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
        fill: true,
        yAxisID: 'y',
      }
    ].concat(comparisonDataSet)
  }
}
