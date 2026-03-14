import React, { ReactNode, useEffect, useMemo, useRef, useState } from 'react'
import * as d3 from 'd3'
import { UIMode, useTheme } from '../../theme-context'
import {
  FormattableMetric,
  MetricFormatterShort
} from '../reports/metric-formatter'
import { DashboardPeriod } from '../../dashboard-time-periods'
import dateFormatter from './date-formatter'
import classNames from 'classnames'
import { ChangeArrow } from '../reports/change-arrow'
import { Metric } from '../../../types/query-api'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const marginLeft = 32

type RevenueMetric = {
  short: string
  value: number
  long: string
  currency: string
}

type ResultItem = {
  dimensions: [string] // one item
  metrics: null | [number] | [RevenueMetric] // one item
}
type MainGraphResponse = {
  results: Array<ResultItem | null>
  comparison_results: Array<
    (ResultItem & { change: [number | null] | null }) | null
  >
  meta: {
    time_labels: string[]
    time_label_result_indices: (number | null)[]
    comparison_time_labels?: string[]
    comparison_time_label_result_indices?: (number | null)[]
  }
  query: {
    interval: string
    date_range: [string, string]
    comparison_date_range?: [string, string]
    dimensions: [string] // one item
    metrics: [string] // one item
  }
}
type GraphDatum = {
  value: number | null // null when graph is not defined
  timeLabel: string | null // null when there's no label
  comparisonValue?: number | null // null when comparison is not defined
  comparisonTimeLabel?: string | null // null when comparison is not defined
  change?: number | null // null when comparison is not defined
}

type XPos = number
type YPos = number
type Point = [XPos, { yMain: YPos | null; yComparison: YPos | null }]

type MainGraphData = MainGraphResponse & { period: DashboardPeriod }

export const MainGraph = ({
  width,
  data
}: {
  width: number
  data: MainGraphData
}) => {
  const { mode } = useTheme()
  const { primaryGradient, secondaryGradient } = paletteByTheme[mode]
  const svgRef = useRef<SVGSVGElement | null>(null)
  const [tooltip, setTooltip] = useState<{
    x: number
    y: number
    selectedIndex: number | null
  }>({ x: 0, y: 0, selectedIndex: null })

  const interval = data.query.dimensions[0].split('time:')[1]
  const metric = data.query.metrics[0] as FormattableMetric
  const period = data.period
  const { remappedData, yMax, hasMultipleYears } = useMemo(
    () => remapToGraphData(data),
    [data]
  )

  const showZoomToPeriod = ['month', 'day'].includes(interval)

  useEffect(() => {
    if (!svgRef.current) {
      return
    }
    console.log('effect running')

    const yMin = 0
    const yDomain = [yMin, yMax]
    // Declare the y (vertical position) scale.
    const y = d3.scaleLinear(yDomain, [height - marginBottom, marginTop]).nice()

    // Declare the x (horizontal position) scale.
    // It's a simple linear axis, one unit for every time bucket
    // because the BE returns equal length buckets
    const xDomain = [0, remappedData.length - 1]
    const x = d3.scaleLinear(xDomain, [marginLeft, width - marginRight])

    const points: Point[] = remappedData.map((d, index) => [
      x(index),
      {
        yMain: d.timeLabel !== null ? y(d.value!) : null,
        yComparison:
          d.comparisonTimeLabel !== null ? y(d.comparisonValue!) : null
      }
    ])

    // Create the SVG container.
    const svg = d3.select(svgRef.current)

    const maxXTicks = 8
    const xTickCount = Math.min(remappedData.length, maxXTicks)
    // Add the x-axis.
    svg
      .append('g')
      .attr('transform', `translate(0,${height - marginBottom})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(xTickCount)
          .tickSize(0)
          .tickFormat((bucketIndex) => {
            // for low tick counts, it may try to render ticks
            // with the index 0.5, 1.5, etc which don't have data defined
            const datum = remappedData[bucketIndex.valueOf()]
            return datum
              ? datum.timeLabel
                ? getXLabel(datum.timeLabel, {
                    shouldShowYear: hasMultipleYears,
                    period,
                    interval
                  })
                : ''
              : ''
          })
      )
      .call((g) => g.select('.domain').remove())
      .call((g) => g.selectAll('.tick').attr('class', 'tick group'))
      .call((g) =>
        g
          .selectAll('.tick text')
          .attr('class', classNames(tickClass, 'translate-y-2'))
      )

    // Add the y-axis, remove the domain line, add grid lines and a label.
    // TODO: make dynamic
    // const maxYTicks = 8
    const yTickCount = 8
    svg
      .append('g')
      .attr('transform', `translate(${marginLeft}, 0)`)
      .call(
        d3
          .axisLeft(y)
          .tickFormat((v) => MetricFormatterShort[metric](v))
          .ticks(yTickCount)
          .tickSize(0)
      )
      .call((g) => g.select('.domain').remove())
      .call((g) => g.selectAll('.tick').attr('class', 'tick group'))
      .call((g) => g.selectAll('.tick text').attr('class', tickClass))
      .call((g) =>
        g
          .selectAll('.tick line')
          .clone()
          .attr('x2', width - marginLeft - marginRight)
          .attr('class', tickLineClass)
      )

    const mainGradientId = addGradient({
      svg,
      id: 'main',
      stopTop: primaryGradient.stopTop,
      stopBottom: primaryGradient.stopBottom
    })
    const comparisonGradientId = addGradient({
      svg,
      id: 'comparisonGradient',
      stopTop: secondaryGradient.stopTop,
      stopBottom: secondaryGradient.stopBottom
    })

    const yBottomEdge = height - marginBottom

    drawAreaUnderLine({
      svg,
      gradientId: mainGradientId,
      isDefined: (d) => d.timeLabel !== null,
      xAccessor: (_d, index) => x(index),
      y0Accessor: yBottomEdge,
      y1Accessor: (d) => y(d.value!),
      datum: remappedData
    })

    drawAreaUnderLine({
      svg,
      gradientId: comparisonGradientId,
      isDefined: (d) => d.comparisonTimeLabel !== null,
      xAccessor: (_d, index) => x(index),
      y0Accessor: yBottomEdge,
      y1Accessor: (d) => y(d.comparisonValue!),
      datum: remappedData
    })

    drawLine({
      svg,
      datum: remappedData,
      isDefined: (d) => d.timeLabel !== null,
      xAccessor: (_d, index) => x(index),
      yAccessor: (d) => y(d.value!),
      className: mainPathClass
    })

    drawLine({
      svg,
      datum: remappedData,
      isDefined: (d) => d.comparisonTimeLabel !== null,
      xAccessor: (_d, index) => x(index),
      yAccessor: (d) => y(d.comparisonValue!),
      className: comparisonPathClass
    })

    const dot = drawDot({ svg, className: mainDotClass })
    const comparisonDot = drawDot({ svg, className: comparisonDotClass })

    svg
      .on('pointermove', (event) => {
        const [xPointer, yPointer] = d3.pointer(event)
        const closestIndexToPointer = d3
          .bisector((dataPoint: Point) => dataPoint[0])
          .center(points, xPointer)
        const [x, yValues] = points[closestIndexToPointer]
        if (yValues.yMain) {
          dot
            .attr('transform', `translate(${x},${yValues.yMain})`)
            .attr('display', null)
        } else {
          dot.attr('display', 'none')
        }
        if (yValues.yComparison) {
          comparisonDot
            .attr('transform', `translate(${x},${yValues.yComparison})`)
            .attr('display', null)
        } else {
          comparisonDot.attr('display', 'none')
        }
        setTooltip({
          selectedIndex: closestIndexToPointer,
          x: xPointer,
          y: yPointer
        })
      })
      .on('pointerleave', () => {
        dot.attr('display', 'none')
        comparisonDot.attr('display', 'none')
        setTooltip({
          selectedIndex: null,
          x: 0,
          y: 0
        })
      })
      .on('touchstart', (event) => event.preventDefault())

    return () => {
      svg.selectAll('*').remove()
    }
  }, [
    primaryGradient,
    secondaryGradient,
    width,
    remappedData,
    yMax,
    hasMultipleYears,
    period,
    interval,
    metric
  ])

  return (
    <div
      className="relative flex justify-center items-center w-full"
      style={{ height: height, maxWidth: width }}
    >
      <svg
        ref={svgRef}
        viewBox={`0 0 ${width} ${height}`}
        className="w-full h-auto cursor-pointer"
      />
      {tooltip.selectedIndex !== null && (
        <GraphTooltip
          width={width}
          showZoomToPeriod={showZoomToPeriod}
          shouldShowYear={hasMultipleYears}
          period={period}
          interval={interval}
          metric={metric}
          x={tooltip.x}
          y={tooltip.y}
          datum={remappedData[tooltip.selectedIndex]}
        />
      )}
    </div>
  )
}

const GraphTooltip = ({
  metric,
  interval,
  period,
  shouldShowYear,
  width,
  x,
  y,
  datum,
  showZoomToPeriod
}: {
  metric: FormattableMetric
  interval: string
  period: DashboardPeriod
  shouldShowYear: boolean
  x: number
  y: number
  datum: GraphDatum
  showZoomToPeriod?: boolean
  width: number
}) => {
  const formatter = MetricFormatterShort[metric]
  const isLeftOfCursor = width - x < 240
  return (
    <div
      style={{
        left: x,
        top: y
      }}
      className={classNames(
        'absolute z-200 bg-gray-800 py-3 px-4 rounded-md z-[100] min-w-[180px] pointer-events-none translate-y-2 shadow shadow-gray-200 dark:shadow-gray-850',
        {
          'translate-x-2': !isLeftOfCursor,
          '-translate-x-full': isLeftOfCursor
        }
      )}
    >
      <aside className="text-sm font-normal text-gray-100 flex flex-col gap-1.5">
        <div className="flex justify-between items-center rounded-sm">
          <span className="font-semibold mr-4 text-xs uppercase">
            {METRIC_LABELS[metric as keyof typeof METRIC_LABELS]}
          </span>
          {datum.comparisonTimeLabel !== null &&
            typeof datum.change === 'number' && (
              <div className="inline-flex items-center space-x-1">
                <ChangeArrow
                  className=""
                  metric={metric as Metric}
                  change={datum.change}
                />
              </div>
            )}
        </div>
        <div className="flex flex-col">
          {typeof datum.timeLabel === 'string' && (
            <div className="flex flex-row justify-between items-center">
              <span className="flex items-center mr-4">
                <div className="size-2 mr-2 rounded-full bg-indigo-400"></div>
                <span>
                  {getXLabel(datum.timeLabel, {
                    period,
                    interval,
                    shouldShowYear
                  })}
                </span>
              </span>
              <span className="font-bold">{formatter(datum.value)}</span>
            </div>
          )}

          {typeof datum.comparisonTimeLabel === 'string' && (
            <div className="flex flex-row justify-between items-center">
              <span className="flex items-center mr-4">
                <div className="size-2 mr-2 rounded-full bg-gray-500"></div>
                <span>
                  {getXLabel(datum.comparisonTimeLabel, {
                    period,
                    interval,
                    shouldShowYear
                  })}
                </span>
              </span>
              <span className="font-bold">
                {formatter(datum.comparisonValue)}
              </span>
            </div>
          )}
        </div>

        {!!showZoomToPeriod && (
          <>
            <hr className="border-gray-600 dark:border-gray-800 my-1" />
            <span className="text-gray-300 dark:text-gray-400 text-xs">
              Click to view {interval}
            </span>
          </>
        )}
      </aside>
    </div>
  )
}

export const MainGraphContainer = React.forwardRef<
  HTMLDivElement,
  { children: ReactNode }
>((props, ref) => {
  return (
    <div className="relative my-4 h-92 w-full z-0" ref={ref}>
      {props.children}
    </div>
  )
})

const getXLabel = (
  xValue: '__blank__' | string,
  {
    shouldShowYear,
    period,
    interval
  }: { shouldShowYear: boolean; interval: string; period: DashboardPeriod }
) => {
  if (xValue == '__blank__') return ''

  if (interval === 'hour' && period !== 'day') {
    const date = dateFormatter({
      interval: 'day',
      longForm: false,
      period: period,
      shouldShowYear,
      isPeriodFull: false
    })(xValue)

    const hour = dateFormatter({
      interval: interval,
      longForm: false,
      period: period,
      shouldShowYear,
      isPeriodFull: false
    })(xValue)

    // Returns a combination of date and hour. This is because
    // small intervals like hour may return multiple days
    // depending on the queried period.
    return `${date}, ${hour}`
  }

  if (interval === 'minute' && period !== 'realtime') {
    return dateFormatter({
      interval: 'hour',
      longForm: false,
      period: period,
      isPeriodFull: false,
      shouldShowYear: false
    })(xValue)
  }

  return dateFormatter({
    interval: interval,
    longForm: false,
    period: period,
    shouldShowYear,
    isPeriodFull: false
  })(xValue)
}

const remapToGraphData = (
  data: MainGraphData
): {
  remappedData: GraphDatum[]
  yMax: number
  hasMultipleYears: boolean
} => {
  let yMax: number = 1
  let firstTimeLabel: null | string = null
  let lastTimeLabel: null | string = null
  const remappedData: GraphDatum[] = new Array(
    Math.max(
      data.meta.comparison_time_label_result_indices?.length ?? 0,
      data.meta.time_label_result_indices.length
    )
  )
    .fill(null)
    .map((_, index) => {
      const [
        timeLabel,
        indexOfResult,
        comparisonTimeLabel,
        indexOfComparisonResult
      ] = [
        // time label, null signifies that the
        data.meta.time_labels[index] ?? null,
        // where to get the main result - the main graph is defined only
        data.meta.time_label_result_indices[index] ?? null,
        // comparison label
        (data.meta.comparison_time_labels &&
          data.meta.comparison_time_labels[index]) ??
          null,
        // where to get the comparison result - the comparison graph is defined only where not null
        (data.meta.comparison_time_label_result_indices &&
          data.meta.comparison_time_label_result_indices[index]) ??
          null
      ]

      const mainResultDefined = typeof timeLabel === 'string'
      const comparisonResultDefined = typeof comparisonTimeLabel === 'string'

      let value: number | null = null
      if (mainResultDefined) {
        if (firstTimeLabel === null) {
          firstTimeLabel = timeLabel
        }
        lastTimeLabel = timeLabel
        if (indexOfResult !== null) {
          const row = data.results[indexOfResult]
          if (row!.metrics![0] === null) {
            value = 0
          } else if (
            typeof row!.metrics![0] === 'object' &&
            row!.metrics![0].hasOwnProperty('value')
          ) {
            value = row!.metrics![0].value
          } else if (typeof row!.metrics![0] === 'number') {
            value = row!.metrics![0]
          }
        } else {
          value = 0
        }
      }
      if (value !== null && value > yMax) {
        yMax = value
      }
      let change = null
      let comparisonValue = null
      if (comparisonResultDefined) {
        if (indexOfComparisonResult !== null) {
          const row = data.comparison_results[indexOfComparisonResult]
          if (row!.metrics![0] === null) {
            comparisonValue = 0
          } else if (
            typeof row!.metrics![0] === 'object' &&
            row!.metrics![0].hasOwnProperty('value')
          ) {
            comparisonValue = row!.metrics![0].value
          } else if (typeof row!.metrics![0] === 'number') {
            comparisonValue = row!.metrics![0]
            change = row!.change !== null ? row!.change[0] : null
          }
        } else {
          comparisonValue = 0
        }
      }

      if (comparisonValue !== null && comparisonValue > yMax) {
        yMax = comparisonValue
      }

      return { value, comparisonValue, timeLabel, comparisonTimeLabel, change }
    })

  const hasMultipleYears =
    firstTimeLabel!.split('-')[0] !== lastTimeLabel!.split('-')[0]

  return {
    remappedData,
    yMax,
    hasMultipleYears
  }
}

const paletteByTheme = {
  [UIMode.dark]: {
    primaryGradient: {
      stopTop: { color: '#4f46e5', opacity: 0.15 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    },
    secondaryGradient: {
      stopTop: { color: '#4f46e5', opacity: 0.05 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    }
  },
  [UIMode.light]: {
    primaryGradient: {
      stopTop: { color: '#4f46e5', opacity: 0.15 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    },
    secondaryGradient: {
      stopTop: { color: '#4f46e5', opacity: 0.05 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    }
  }
}

const tickLineClass =
  'stroke-gray-150 dark:stroke-gray-800/75 group-first:stroke-gray-300 dark:group-first:stroke-gray-700'
const tickClass = 'fill-gray-500 dark:fill-gray-400 text-xs'

const mainDotClass = 'fill-indigo-500 dark:fill-indigo-400'
const comparisonDotClass = 'fill-indigo-500/20 dark:fill-indigo-400/20'

const sharedPathClass = 'stroke-2'
const mainPathClass = 'stroke-indigo-500 dark:stroke-indigo-400 z-2'
const comparisonPathClass = 'stroke-indigo-500/20 dark:stroke-indigo-400/20 z-1'

const METRIC_LABELS = {
  visitors: 'Visitors',
  pageviews: 'Pageviews',
  events: 'Total conversions',
  views_per_visit: 'Views per visit',
  visits: 'Visits',
  bounce_rate: 'Bounce rate',
  visit_duration: 'Visit duration',
  conversions: 'Converted visitors',
  conversion_rate: 'Conversion rate',
  average_revenue: 'Average revenue',
  total_revenue: 'Total revenue',
  scroll_depth: 'Scroll depth',
  time_on_page: 'Time on page'
}

const addGradient = ({
  svg,
  id,
  stopTop,
  stopBottom
}: {
  svg: SelectedSVG
  id: string
  stopTop: { color: string; opacity: number }
  stopBottom: { color: string; opacity: number }
}): string => {
  const grad = svg
    .append('defs')
    .append('linearGradient')
    .attr('id', id)
    .attr('x1', '0%')
    .attr('y1', '0%') // top
    .attr('x2', '0%')
    .attr('y2', `100%`) // bottom

  grad
    .append('stop')
    .attr('offset', '0%')
    .attr('stop-color', stopTop.color)
    .attr('stop-opacity', stopTop.opacity)

  grad
    .append('stop')
    .attr('offset', '100%')
    .attr('stop-color', stopBottom.color)
    .attr('stop-opacity', stopBottom.opacity)
  return id
}

const drawAreaUnderLine = ({
  svg,
  gradientId,
  isDefined,
  xAccessor,
  y0Accessor,
  y1Accessor,
  datum
}: {
  svg: SelectedSVG
  gradientId: string
  isDefined: (d: GraphDatum) => boolean
  xAccessor: (d: GraphDatum, index: number) => number
  y0Accessor: number
  y1Accessor: (d: GraphDatum, index: number) => number
  datum: GraphDatum[]
}) => {
  const area = d3
    .area<GraphDatum>()
    .x(xAccessor)
    .defined(isDefined)
    .y0(y0Accessor) // bottom edge
    .y1(y1Accessor) // top edge follows the data

  // draw the filled area with the gradient
  svg
    .append('path')
    .datum(datum)
    .attr('fill', `url(#${gradientId})`)
    .attr('d', area)
}

const drawLine = ({
  svg,
  datum,
  isDefined,
  xAccessor,
  yAccessor,
  className
}: {
  svg: SelectedSVG
  datum: GraphDatum[]
  isDefined: (d: GraphDatum) => boolean
  xAccessor: (d: GraphDatum, index: number) => number
  yAccessor: (d: GraphDatum, index: number) => number
  className?: string
}) => {
  const line = d3
    .line<GraphDatum>()
    .defined(isDefined)
    .x(xAccessor)
    .y(yAccessor)

  svg
    .append('path')
    .attr('fill', 'none')
    .attr('class', classNames(sharedPathClass, className))
    .attr('stroke-linejoin', 'round')
    .attr('stroke-linecap', 'round')
    .datum(datum)
    .attr('d', line)
}

const drawDot = ({
  svg,
  className
}: {
  svg: SelectedSVG
  className: string
}) => {
  const dot = svg.append('g').attr('display', 'none')
  dot.append('circle').attr('r', 2.5).attr('class', className)
  return dot
}

type SelectedSVG = d3.Selection<SVGSVGElement, unknown, null, undefined>
