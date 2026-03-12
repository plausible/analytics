import React, { ReactNode, useEffect, useRef } from 'react'
import * as d3 from 'd3'
import { UIMode, useTheme } from '../../theme-context'
import {
  FormattableMetric,
  MetricFormatterShort
} from '../reports/metric-formatter'
import { DashboardPeriod } from '../../dashboard-time-periods'
import dateFormatter from './date-formatter'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const marginLeft = 32

type ResultItem = {
  dimensions: [string] // one item
  metrics: null | [number] // one item
  comparison: unknown
}
type MainGraphResponse = {
  results: Array<ResultItem | null>
  meta: { time_labels: string[] }
  query: {
    interval: string
    date_range: string
    dimensions: [string] // one item
    metrics: [string] // one item
  }
}
type GraphDatum = { value: number; date: string }

type XPos = number
type YPos = number
type SeriesId = string
type Point = [XPos, YPos, SeriesId]

type MainGraphData = MainGraphResponse & { period: DashboardPeriod }

export const MainGraph = ({
  width,
  data
}: {
  width: number
  data: MainGraphData
}) => {
  const { mode } = useTheme()
  const { primaryGradient } = paletteByTheme[mode]
  const svgRef = useRef<SVGSVGElement | null>(null)

  useEffect(() => {
    if (!svgRef.current) {
      return
    }

    const interval = data.query.dimensions[0].split('time:')[1]
    const period = data.period

    const remappedData = remapToGraphData(data)

    const minDate = remappedData[0].date
    const maxDate = remappedData[remappedData.length - 1].date

    const hasMultipleYears = minDate.split('-')[0] !== maxDate.split('-')[0]

    // Declare the x (horizontal position) scale.
    // It's a simple linear axis, one unit for every time bucket
    // because the BE is sending equal length buckets
    const x = d3.scaleLinear(
      [0, remappedData.length - 1],
      [marginLeft, width - marginRight]
    )

    // Declare the y (vertical position) scale.
    const yMin = 0
    // TODO: find highest item during remapping
    const yMax = remappedData.reduce(
      (acc, current) =>
        current.value && current.value > acc ? current.value : acc,
      0
    )

    const yDomain = yMax > yMin ? [yMin, yMax] : [yMin, yMin + 1]
    const y = d3.scaleLinear(yDomain, [height - marginBottom, marginTop]).nice()

    const points: Point[] = remappedData.map((d, index) => [
      x(index),
      y(d.value),
      'v'
    ])

    const groups = d3.rollup(
      points,
      (point) => Object.assign(point, { z: point[0][2] }),
      (point) => point[2]
    )

    // Create the SVG container.
    const svg = d3.select(svgRef.current)

    // TODO: make dynamic
    const maxXTicks = 8
    const xTickCount =
      remappedData.length % 7 === 0
        ? Math.min(7 + 1, maxXTicks)
        : Math.min(remappedData.length, maxXTicks)

    // Add the x-axis.
    svg
      .append('g')
      .attr('transform', `translate(0,${height - marginBottom})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(xTickCount)
          .tickSize(0)
          .tickFormat((index) =>
            getXLabel(remappedData[index.valueOf()].date, {
              shouldShowYear: hasMultipleYears,
              period,
              interval
            })
          )
      )
      .call((g) => g.select('.domain').remove())
      .call((g) => g.selectAll('.tick text').attr('class', tickClass))

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
          .tickFormat((v) =>
            MetricFormatterShort[data.query.metrics[0] as FormattableMetric](v)
          )
          .ticks(yTickCount)
          .tickSize(0)
      )
      .call((g) => g.select('.domain').remove())
      .call((g) =>
        g
          .selectAll('.tick')
          .attr('class', 'tick group')
          .selectAll('.text')
          .attr('class', tickClass)
      )
      .call((g) =>
        g
          .selectAll('.tick line')
          .clone()
          .attr('x2', width - marginLeft - marginRight)
          .attr('class', tickLineClass)
      )

    const addGradient = (): string => {
      // add gradient
      const id = 'areaGradient'
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
        .attr('stop-color', primaryGradient[0][0])
        .attr('stop-opacity', primaryGradient[0][1])

      grad
        .append('stop')
        .attr('offset', '100%')
        .attr('stop-color', primaryGradient[1][0])
        .attr('stop-opacity', primaryGradient[1][1])
      return id
    }

    const paintUnderLine = (
      gradientId: string,
      y1Accessor: (d: GraphDatum, index: number) => number
    ) => {
      const area = d3
        .area<GraphDatum>()
        .x((_d, index) => x(index))
        .y0(height - marginBottom) // bottom edge
        .y1(y1Accessor) // top edge follows the data

      // draw the filled area with the gradient
      svg
        .append('path')
        .datum(remappedData)
        .attr('fill', `url(#${gradientId})`)
        .attr('d', area)
    }

    const drawLine = () => {
      const line = d3.line<Point>()

      svg
        .append('g')
        .attr('fill', 'none')
        .attr('class', 'stroke-[#6366f1] stroke-2 z-1')
        .attr('stroke-linejoin', 'round')
        .attr('stroke-linecap', 'round')
        .selectAll('path')
        .data(groups.values())
        .join('path')
        .attr('d', line)
    }

    const drawDot = () => {
      const dot = svg.append('g').attr('display', 'none')
      dot.append('circle').attr('r', 2.5).attr('class', 'fill-[#6366f1]')
      return dot
    }

    const gradientId = addGradient()
    paintUnderLine(gradientId, (d) => y(d.value))
    drawLine()
    const dot = drawDot()

    svg
      .on('pointermove', (event) => {
        const [xPointer] = d3.pointer(event)
        const closestIndexToPointer = d3
          .bisector((dataPoint: Point) => dataPoint[0])
          .center(points, xPointer)
        const [x, y, _k] = points[closestIndexToPointer]
        dot.attr('transform', `translate(${x},${y})`).attr('display', null)
      })
      .on('pointerleave', () => {
        dot.attr('display', 'none')
      })
      .on('touchstart', (event) => event.preventDefault())

    return () => {
      svg.selectAll('*').remove()
    }
  }, [primaryGradient, width, data])

  return (
    <div
      className="relative flex justify-center items-center w-full"
      style={{ height: height, maxWidth: width }}
    >
      <svg
        ref={svgRef}
        viewBox={`0 0 ${width} ${height}`}
        className="w-full h-auto"
      />
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

const remapToGraphData = (data: MainGraphData): GraphDatum[] =>
  data.meta.time_labels.map((label, _i) => {
    const dataPoint = data.results.find((d) => d?.dimensions[0] === label)
    const value = (dataPoint?.metrics && dataPoint.metrics[0]) ?? null
    return fillMissingValue({
      value,
      date: label
    })
  })

function fillMissingValue<
  D extends { value: null | number | { value: number } }
>(d: D): D & { value: number } {
  if (d.value === null) {
    return { ...d, value: 0 }
  }
  // Revenue metrics are returned as objects with a `value` property
  if (typeof d.value === 'object' && d.value.hasOwnProperty('value')) {
    return { ...d, value: d.value.value }
  }
  return d as D & { value: number }
}

const paletteByTheme = {
  [UIMode.dark]: {
    primaryGradient: [
      ['#4f46e5', 0.15],
      ['#4f46e5', 0]
    ],
    secondaryGradient: [
      ['#4f46e5', 0.05],
      ['#4f46e5', 0]
    ]
  },
  [UIMode.light]: {
    primaryGradient: [
      ['#4f46e5', 0.15],
      ['#4f46e5', 0]
    ],
    secondaryGradient: [
      ['#4f46e5', 0.05],
      ['#4f46e5', 0]
    ]
  }
} as const

const tickLineClass =
  'stroke-[#ececee] dark:stroke-[#27272a75] group-first:stroke-[#a1a1aa]'
const tickClass = 'fill-currentColor dark:fill-[#a1a1aa]'
