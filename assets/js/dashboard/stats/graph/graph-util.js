import numberFormatter, {durationFormatter} from '../../util/number-formatter'

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
