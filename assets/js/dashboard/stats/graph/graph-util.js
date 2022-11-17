import numberFormatter, {durationFormatter} from '../../util/number-formatter'
import {parseUTCDate, formatMonthYYYY, formatDay, formatDayShort} from '../../util/date'

export const INTERVALS = ["month", "week", "date", "hour", "minute"]

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

export const dateFormatter = (interval, longForm, period, full) => {
  return function(isoDate, _index, _ticks) {
    const date = parseUTCDate(isoDate)
    const minutes = date.getMinutes();

    const dateFormat = Intl.DateTimeFormat(navigator.language, { hour: 'numeric' })
    const twelveHourClock = dateFormat.resolvedOptions().hour12

    const getFormattedHours = () => {
      const monthIndex = 1
      const dateParts = isoDate.split(/[^0-9]/);
      dateParts[monthIndex] = dateParts[monthIndex] - 1

      const localDate = new Date(...dateParts)
      return dateFormat.format(localDate)
    }

    if (interval === 'month') {
      if (longForm) {
        return (full ? '' : 'Partial ') + formatMonthYYYY(date);
      } else {
        return formatMonthYYYY(date);
      }
    } else if (interval === 'week') {
      if (longForm) {
        return `${full ? 'W' : 'Partial w'}eek of ` + formatDayShort(date);
      } else {
        return formatDayShort(date);
      }
    } else if (interval === 'date') {
      if (longForm) {
        return formatDay(date);
      } else {
        return formatDayShort(date);
      }
    } else if (interval === 'hour') {
      if (twelveHourClock) {
        return getFormattedHours().replace(' ', '').toLowerCase()
      } else {
        return getFormattedHours().replace(/[^0-9]/g, '').concat(":00")
      }
    } else if (interval === 'minute' && period === 'realtime') {
      if (longForm) {
        const minutesAgo = Math.abs(isoDate)
        return minutesAgo === 1 ? '1 minute ago' : minutesAgo + ' minutes ago'
      } else {
        return isoDate + 'm'
      }
    } else if (interval === 'minute') {
      if (twelveHourClock) {
        return getFormattedHours().replace(' ', ':' + (minutes < 10 ? `0${minutes}` : minutes)).toLowerCase()
      } else {
        return getFormattedHours().replace(/[^0-9]/g, '').concat(":" + (minutes < 10 ? `0${minutes}` : minutes))
      }
    }
  }
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

    function getBody(bodyItem) {
      return bodyItem.lines;
    }

    // Returns a string describing the bucket. Used when hovering the graph to
    // show time buckets.
    function renderBucketLabel(label) {
      const isPeriodFull = graphData.full_intervals?.[label]
      const formattedLabel = dateFormatter(graphData.interval, true, query.period, isPeriodFull)(label)

      if (query.period === 'realtime') {
        return dateFormatter(graphData.interval, true, query.period)(label)
      }

      if (graphData.interval === 'hour' || graphData.interval == 'minute') {
        const date = dateFormatter("date", true, query.period)(label)
        return `${date}, ${formattedLabel}`
      }

      return formattedLabel
    }

    // Set Tooltip Body
    if (tooltipModel.body) {
      var bodyLines = tooltipModel.body.map(getBody);

      // Remove duplicated line on overlap between dashed and normal
      if (bodyLines.length == 3) {
        bodyLines[1] = false
      }

      const data = tooltipModel.dataPoints[0]
      const label = graphData.labels[data.dataIndex]
      const point = data.raw || 0

      let innerHtml = `
      <div class='text-gray-100 flex flex-col'>
        <div class='flex justify-between items-center'>
          <span class='font-semibold mr-4 text-lg'>${METRIC_LABELS[metric]}</span>
        </div>
        <div class='flex flex-col'>
          <div class='flex flex-row justify-between items-center'>
            <span class='flex items-center mr-4'>
              <div class='w-3 h-3 mr-1 rounded-full' style='background-color: rgba(101,116,205)'></div>
              <span>${renderBucketLabel(label)}</span>
            </span>
            <span class='text-base font-bold'>${METRIC_FORMATTER[metric](point)}</span>
          </div>
        </div>
        <span class='font-semibold italic'>${graphData.interval === 'month' ? 'Click to view month' : graphData.interval === 'date' ? 'Click to view day' : ''}</span>
      </div>
      `;

      tooltipEl.innerHTML = innerHtml;
    }
    tooltipEl.style.display = null;
  }
}

export const buildDataSet = (plot, present_index, ctx, label, isPrevious) => {
  var gradient = ctx.createLinearGradient(0, 0, 0, 300);
  var prev_gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(101,116,205, 0.2)');
  gradient.addColorStop(1, 'rgba(101,116,205, 0)');
  prev_gradient.addColorStop(0, 'rgba(101,116,205, 0.075)');
  prev_gradient.addColorStop(1, 'rgba(101,116,205, 0)');

  if (!isPrevious) {
    if (present_index) {
      var dashedPart = plot.slice(present_index - 1, present_index + 1);
      var dashedPlot = (new Array(present_index - 1)).concat(dashedPart)
      const _plot = [...plot]
      for (var i = present_index; i < _plot.length; i++) {
        _plot[i] = undefined
      }

      return [{
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
      }]
    } else {
      return [{
        label,
        data: plot,
        borderWidth: 3,
        borderColor: 'rgba(101,116,205)',
        pointHoverBackgroundColor: 'rgba(71, 87, 193)',
        pointBorderColor: 'transparent',
        pointHoverRadius: 4,
        backgroundColor: gradient,
        fill: true,
      }]
    }
  } else {
    return [{
      label,
      data: plot,
      borderWidth: 2,
      borderColor: 'rgba(166,187,210,0.5)',
      pointHoverBackgroundColor: 'rgba(166,187,210,0.8)',
      pointBorderColor: 'transparent',
      pointHoverBorderColor: 'transparent',
      pointHoverRadius: 4,
      backgroundColor: prev_gradient,
      fill: true,
    }]
  }
}
