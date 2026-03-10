import React from 'react'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { useDashboardStateContext } from '../../dashboard-state-context'
import Chart from 'chart.js/auto'
import GraphTooltip from './graph-tooltip'
import { buildDataSet, METRIC_LABELS, hasMultipleYears } from './graph-util'
import dateFormatter from './date-formatter'
import classNames from 'classnames'
import { hasConversionGoalFilter } from '../../util/filters'
import { MetricFormatterShort } from '../reports/metric-formatter'
import { UIMode, useTheme } from '../../theme-context'
import { Transition } from '@headlessui/react'
import equal from 'fast-deep-equal'

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
    this.updateWindowDimensions = this.updateWindowDimensions.bind(this)
  }

  getGraphMetric() {
    let metric = this.props.graphData.metric

    if (
      metric == 'visitors' &&
      hasConversionGoalFilter(this.props.dashboardState)
    ) {
      return 'conversions'
    } else {
      return metric
    }
  }

  buildXTicksCallback() {
    const { graphData, dashboardState } = this.props
    const shouldShowYear = hasMultipleYears(graphData)
    return function (val, _index, _ticks) {
      if (this.getLabelForValue(val) == '__blank__') return ''

      if (graphData.interval === 'hour' && dashboardState.period !== 'day') {
        const date = dateFormatter({
          interval: 'day',
          longForm: false,
          period: dashboardState.period,
          shouldShowYear
        })(this.getLabelForValue(val))

        const hour = dateFormatter({
          interval: graphData.interval,
          longForm: false,
          period: dashboardState.period,
          shouldShowYear
        })(this.getLabelForValue(val))

        return `${date}, ${hour}`
      }

      if (
        graphData.interval === 'minute' &&
        dashboardState.period !== 'realtime'
      ) {
        return dateFormatter({
          interval: 'hour',
          longForm: false,
          period: dashboardState.period
        })(this.getLabelForValue(val))
      }

      return dateFormatter({
        interval: graphData.interval,
        longForm: false,
        period: dashboardState.period,
        shouldShowYear
      })(this.getLabelForValue(val))
    }
  }

  updateChart() {
    const { graphData, dashboardState, theme } = this.props
    const metric = this.getGraphMetric()
    const dataSet = buildDataSet(
      graphData.plot,
      graphData.comparison_plot,
      graphData.present_index,
      this.ctx,
      METRIC_LABELS[metric]
    )

    const maxY = calculateMaximumY(dataSet)

    this.chart.data.labels = graphData.labels
    this.chart.data.datasets = dataSet
    this.chart.options.scales.y.suggestedMax = maxY
    this.chart.options.scales.yComparison.suggestedMax = maxY
    this.chart.options.scales.y.ticks.callback = MetricFormatterShort[metric]
    this.chart.options.scales.y.ticks.color =
      theme.mode === UIMode.dark ? 'rgb(161, 161, 170)' : undefined
    this.chart.options.scales.y.grid.color =
      theme.mode === UIMode.dark
        ? 'rgba(39, 39, 42, 0.75)'
        : 'rgb(236, 236, 238)'
    this.chart.options.scales.x.ticks.color =
      theme.mode === UIMode.dark ? 'rgb(161, 161, 170)' : undefined
    this.chart.options.scales.x.ticks.callback = this.buildXTicksCallback()
    this.chart.options.plugins.tooltip.external = GraphTooltip(
      graphData,
      metric,
      dashboardState,
      theme
    )

    this.chart.update()
  }

  regenerateChart() {
    const graphEl = document.getElementById('main-graph-canvas')
    this.ctx = graphEl.getContext('2d')

    this.chart = new Chart(this.ctx, {
      type: 'line',
      data: { labels: [], datasets: [] },
      options: {
        animation: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: false,
            mode: 'index',
            intersect: false,
            position: 'average',
            external: () => {}
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
            ticks: {},
            grid: { zeroLineColor: 'transparent', drawBorder: false }
          },
          yComparison: { min: 0, display: false, grid: { display: false } },
          x: { grid: { display: false }, ticks: {} }
        },
        interaction: { mode: 'index', intersect: false }
      }
    })

    this.updateChart()
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
      this.regenerateChart()
    }
    window.addEventListener('mousemove', this.repositionTooltip)
  }

  componentDidUpdate(prevProps) {
    const { graphData, theme } = this.props
    const tooltip = document.getElementById('chartjs-tooltip-main')
    const dataChanged = !equal(graphData, prevProps.graphData)
    if (dataChanged || theme.mode !== prevProps.theme.mode) {
      if (tooltip) {
        tooltip.style.display = 'none'
      }

      if (graphData) {
        if (this.chart) {
          this.updateChart()
        } else {
          this.regenerateChart()
        }
      }
    }

    if (!graphData) {
      if (this.chart) {
        this.chart.destroy()
        this.chart = null
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
        search: (searchRecord) => ({ ...searchRecord, period: 'month', date })
      })
    } else if (this.props.graphData.interval === 'day') {
      this.props.navigate({
        search: (searchRecord) => ({ ...searchRecord, period: 'day', date })
      })
    }
  }

  render() {
    const { graphData } = this.props
    const canvasClass = classNames('select-none', {
      'cursor-pointer': !['minute', 'hour'].includes(graphData?.interval)
    })

    return (
      <Transition
        show={true}
        appear={true}
        as={React.Fragment}
        enter="transition ease-in duration-100"
        enterFrom="opacity-0"
        enterTo="opacity-100"
      >
        <canvas id="main-graph-canvas" className={canvasClass} />
      </Transition>
    )
  }
}

export function LineGraphContainer(props) {
  return <div className="relative my-4 h-92 w-full z-0">{props.children}</div>
}

export default function LineGraphWrapped(props) {
  const { dashboardState } = useDashboardStateContext()
  const navigate = useAppNavigate()
  const theme = useTheme()
  return (
    <LineGraph
      {...props}
      navigate={navigate}
      dashboardState={dashboardState}
      theme={theme}
    />
  )
}
