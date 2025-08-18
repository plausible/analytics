import React from 'react'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { useQueryContext } from '../../query-context'
import Chart from 'chart.js/auto'
import GraphTooltip from './graph-tooltip'
import { buildDataSet, METRIC_LABELS, hasMultipleYears } from './graph-util'
import dateFormatter from './date-formatter'
import FadeIn from '../../fade-in'
import classNames from 'classnames'
import { hasConversionGoalFilter } from '../../util/filters'
import { MetricFormatterShort } from '../reports/metric-formatter'

const calculateMaximumY = function (dataset) {
  const yAxisValues = dataset
    .flatMap((item) => item.data)
    .map((item) => item || 0)

  if (yAxisValues) {
    return Math.max(...yAxisValues)
  } else {
    return 1
  }
}

class LineGraph extends React.Component {
  constructor(props) {
    super(props)
    this.regenerateChart = this.regenerateChart.bind(this)
    this.updateWindowDimensions = this.updateWindowDimensions.bind(this)
  }

  getGraphMetric() {
    let metric = this.props.graphData.metric

    if (metric == 'visitors' && hasConversionGoalFilter(this.props.query)) {
      return 'conversions'
    } else {
      return metric
    }
  }

  regenerateChart() {
    const { graphData, query } = this.props
    const metric = this.getGraphMetric()
    const graphEl = document.getElementById('main-graph-canvas')
    this.ctx = graphEl.getContext('2d')
    const dataSet = buildDataSet(
      graphData.plot,
      graphData.comparison_plot,
      graphData.present_index,
      this.ctx,
      METRIC_LABELS[metric]
    )

    return new Chart(this.ctx, {
      type: 'line',
      data: {
        labels: graphData.labels,
        datasets: dataSet
      },
      options: {
        animation: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: false,
            mode: 'index',
            intersect: false,
            position: 'average',
            external: GraphTooltip(graphData, metric, query)
          }
        },
        responsive: true,
        maintainAspectRatio: false,
        onResize: this.updateWindowDimensions,
        elements: { line: { tension: 0 }, point: { radius: 0 } },
        onClick: this.maybeHopToHoveredPeriod.bind(this),
        scale: {
          ticks: { precision: 0, maxTicksLimit: 8 }
        },
        scales: {
          y: {
            min: 0,
            suggestedMax: calculateMaximumY(dataSet),
            ticks: {
              callback: MetricFormatterShort[metric],
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            },
            grid: {
              zeroLineColor: 'transparent',
              drawBorder: false
            }
          },
          yComparison: {
            min: 0,
            suggestedMax: calculateMaximumY(dataSet),
            display: false,
            grid: { display: false }
          },
          x: {
            grid: { display: false },
            ticks: {
              callback: function (val, _index, _ticks) {
                if (this.getLabelForValue(val) == '__blank__') return ''

                const shouldShowYear = hasMultipleYears(graphData)

                if (graphData.interval === 'hour' && query.period !== 'day') {
                  const date = dateFormatter({
                    interval: 'day',
                    longForm: false,
                    period: query.period,
                    shouldShowYear
                  })(this.getLabelForValue(val))

                  const hour = dateFormatter({
                    interval: graphData.interval,
                    longForm: false,
                    period: query.period,
                    shouldShowYear
                  })(this.getLabelForValue(val))

                  // Returns a combination of date and hour. This is because
                  // small intervals like hour may return multiple days
                  // depending on the query period.
                  return `${date}, ${hour}`
                }

                if (
                  graphData.interval === 'minute' &&
                  query.period !== 'realtime'
                ) {
                  return dateFormatter({
                    interval: 'hour',
                    longForm: false,
                    period: query.period
                  })(this.getLabelForValue(val))
                }

                return dateFormatter({
                  interval: graphData.interval,
                  longForm: false,
                  period: query.period,
                  shouldShowYear
                })(this.getLabelForValue(val))
              },
              color: this.props.darkTheme ? 'rgb(243, 244, 246)' : undefined
            }
          }
        },
        interaction: {
          mode: 'index',
          intersect: false
        }
      }
    })
  }

  repositionTooltip(e) {
    const tooltipEl = document.getElementById('chartjs-tooltip-main')
    if (tooltipEl && window.innerWidth >= 768) {
      if (e.clientX > 0.66 * window.innerWidth) {
        tooltipEl.style.right =
          window.innerWidth - e.clientX + window.pageXOffset + 'px'
        tooltipEl.style.left = null
      } else {
        tooltipEl.style.right = null
        tooltipEl.style.left = e.clientX + window.pageXOffset + 'px'
      }
      tooltipEl.style.top = e.clientY + window.pageYOffset + 'px'
      tooltipEl.style.opacity = 1
    }
  }

  componentDidMount() {
    if (this.props.graphData) {
      this.chart = this.regenerateChart()
    }
    window.addEventListener('mousemove', this.repositionTooltip)
  }

  componentDidUpdate(prevProps) {
    const { graphData, darkTheme } = this.props
    const tooltip = document.getElementById('chartjs-tooltip-main')

    if (
      graphData !== prevProps.graphData ||
      darkTheme !== prevProps.darkTheme
    ) {
      if (graphData) {
        if (this.chart) {
          this.chart.destroy()
        }
        this.chart = this.regenerateChart()
        this.chart.update()
      }

      if (tooltip) {
        tooltip.style.display = 'none'
      }
    }

    if (!graphData) {
      if (this.chart) {
        this.chart.destroy()
      }

      if (tooltip) {
        tooltip.style.display = 'none'
      }
    }
  }

  componentWillUnmount() {
    // Ensure that the tooltip doesn't hang around when we are loading more data
    const tooltip = document.getElementById('chartjs-tooltip-main')
    if (tooltip) {
      tooltip.style.opacity = 0
      tooltip.style.display = 'none'
    }
    window.removeEventListener('mousemove', this.repositionTooltip)
  }

  /**
   * The current ticks' limits are set to treat iPad (regular/Mini/Pro) as a regular screen.
   * @param {*} chart - The chart instance.
   * @param {*} dimensions - An object containing the new dimensions *of the chart.*
   */
  updateWindowDimensions(chart, dimensions) {
    chart.options.scales.x.ticks.maxTicksLimit = dimensions.width < 720 ? 5 : 8
  }

  maybeHopToHoveredPeriod(e) {
    const element = this.chart.getElementsAtEventForMode(e, 'index', {
      intersect: false
    })[0]
    const date =
      this.props.graphData.labels[element.index] ||
      this.props.graphData.comparison_labels[element.index]

    if (this.props.graphData.interval === 'month') {
      this.props.navigate({
        search: (search) => ({ ...search, period: 'month', date })
      })
    } else if (this.props.graphData.interval === 'day') {
      this.props.navigate({
        search: (search) => ({ ...search, period: 'day', date })
      })
    }
  }

  render() {
    const { graphData } = this.props
    const canvasClass = classNames('mt-4 select-none', {
      'cursor-pointer': !['minute', 'hour'].includes(graphData?.interval)
    })

    return (
      <FadeIn show={graphData}>
        <div className="relative h-96 print:h-auto print:pb-8 w-full z-0">
          <canvas id="main-graph-canvas" className={canvasClass}></canvas>
        </div>
      </FadeIn>
    )
  }
}

export default function LineGraphWrapped(props) {
  const { query } = useQueryContext()
  const navigate = useAppNavigate()
  return <LineGraph {...props} navigate={navigate} query={query} />
}
