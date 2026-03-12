import React, { ReactNode, useEffect, useRef } from 'react'
import * as d3 from 'd3'
import { UIMode, useTheme } from '../../theme-context'
import {
  FormattableMetric,
  MetricFormatterShort
} from '../reports/metric-formatter'
import { DashboardPeriod } from '../../dashboard-time-periods'
import dateFormatter from './date-formatter'
import classNames from 'classnames'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const marginLeft = 32

type ResultItem = {
  dimensions: [string] // one item
  metrics: null | [number] | [{ value: number }] // one item
  comparison: { metrics: [number]; change: [number]; dimensions: [string] }
}
type MainGraphResponse = {
  results: Array<ResultItem | null>
  comparison_results: Array<ResultItem | null>
  meta: {
    time_labels: string[]
    time_label_result_indices: (number | null)[]
    comparison_time_labels: string[]
    comparison_time_label_result_indices: (number | null)[]
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
  change?: number // null when comparison is not defined
}

type XPos = number
type YPos = number
type Point = [XPos, YPos[]]

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

    const {
      remappedData,
      yMax,
      resultDefinedRange,
      comparisonResultDefinedRange
    } = remapToGraphData(data)
    console.log({
      remappedData,
      yMax,
      resultDefinedRange,
      comparisonResultDefinedRange
    })
    const yMin = 0
    const yDomain = [yMin, yMax]
    // Declare the y (vertical position) scale.
    const y = d3.scaleLinear(yDomain, [height - marginBottom, marginTop]).nice()

    // Declare the x (horizontal position) scale.
    // It's a simple linear axis, one unit for every time bucket
    // because the BE returns equal length buckets
    const xDomain = [0, remappedData.length - 1]
    console.log(xDomain)
    const x = d3.scaleLinear(xDomain, [marginLeft, width - marginRight])

    const minDate = remappedData[resultDefinedRange[0]].timeLabel!
    const maxDate = remappedData[resultDefinedRange[1]].timeLabel!
    console.log(minDate, maxDate)
    const hasMultipleYears = minDate.split('-')[0] !== maxDate.split('-')[0]

    const points: Point[] = remappedData.map((d, index) => [
      x(index),
      [
        [d.timeLabel, d.value] as const,
        [d.comparisonTimeLabel, d.comparisonValue] as const
      ]
        .filter(([label, _v]) => label !== null)
        .map(([_label, v]) => y(v!))
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
          .tickFormat((v) =>
            MetricFormatterShort[data.query.metrics[0] as FormattableMetric](v)
          )
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

    const addGradient = (): string => {
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
      isDefined: (d: GraphDatum) => boolean,
      y1Accessor: (d: GraphDatum, index: number) => number
    ) => {
      const area = d3
        .area<GraphDatum>()
        .x((_d, index) => x(index))
        .defined(isDefined)
        .y0(height - marginBottom) // bottom edge
        .y1(y1Accessor) // top edge follows the data

      // draw the filled area with the gradient
      svg
        .append('path')
        .datum(remappedData)
        .attr('fill', `url(#${gradientId})`)
        .attr('d', area)
    }

    const drawLine = (
      dataset: GraphDatum[],
      isDefined: (d: GraphDatum) => boolean,
      yAccessor: (d: GraphDatum, index: number) => number
    ) => {
      const line = d3
        .line<GraphDatum>()
        .defined(isDefined)
        .x((_d, index) => x(index))
        .y(yAccessor)

      svg
        .append('path')
        .attr('fill', 'none')
        .attr('class', pathClass)
        .attr('stroke-linejoin', 'round')
        .attr('stroke-linecap', 'round')
        .datum(dataset)
        .attr('d', line)
    }

    const drawDot = () => {
      const dot = svg.append('g').attr('display', 'none')
      dot.append('circle').attr('r', 2.5).attr('class', dotClass)
      return dot
    }

    const gradientId = addGradient()
    paintUnderLine(
      gradientId,
      ({ timeLabel }) => timeLabel !== null,
      ({ value }) => y(value!)
    )
    drawLine(
      remappedData,
      (d) => d.timeLabel !== null,
      (d) => y(d.value!)
    )
    
    const dot = drawDot()

    svg
      .on('pointermove', (event) => {
        const [xPointer] = d3.pointer(event)
        const closestIndexToPointer = d3
          .bisector((dataPoint: Point) => dataPoint[0])
          .center(points, xPointer)
        const [x, yValues] = points[closestIndexToPointer]
        dot
          .attr('transform', `translate(${x},${yValues[0]})`)
          .attr('display', null)
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

const remapToGraphData = (
  data: MainGraphData
): {
  remappedData: GraphDatum[]
  yMax: number
  resultDefinedRange: [number, number]
  comparisonResultDefinedRange: null | [number, number]
} => {
  let yMax: number = 1
  const resultDefinedFromBucketIndex = 0
  let resultDefinedToBucketIndex = 0

  let comparisonDefinedFromBucketIndex: null | number = null
  let comparisonDefinedToBucketIndex: null | number = null

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
        data.meta.comparison_time_labels[index] ?? null,
        // where to get the comparison result - the comparison graph is defined only where not null
        data.meta.comparison_time_label_result_indices[index] ?? null
      ]

      const mainResultDefined = typeof timeLabel === 'string'
      const comparisonResultDefined = typeof comparisonTimeLabel === 'string'

      let value: number | null = null
      if (mainResultDefined) {
        resultDefinedToBucketIndex = index
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

      let comparisonValue = null
      if (comparisonResultDefined) {
        if (comparisonDefinedFromBucketIndex === null) {
          comparisonDefinedFromBucketIndex = index
        }
        comparisonDefinedToBucketIndex = index
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
          }
        } else {
          comparisonValue = 0
        }
      }

      if (comparisonValue !== null && comparisonValue > yMax) {
        yMax = comparisonValue
      }

      return { value, comparisonValue, timeLabel, comparisonTimeLabel }
    })

  return {
    remappedData,
    yMax,
    resultDefinedRange: [
      resultDefinedFromBucketIndex,
      resultDefinedToBucketIndex
    ],
    comparisonResultDefinedRange:
      comparisonDefinedFromBucketIndex !== null &&
      comparisonDefinedToBucketIndex !== null
        ? [comparisonDefinedFromBucketIndex, comparisonDefinedToBucketIndex]
        : null
  }
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
  'stroke-gray-150 dark:stroke-gray-800/75 group-first:stroke-gray-300 dark:group-first:stroke-gray-700'
const tickClass = 'fill-gray-500 dark:fill-gray-400 text-xs'
// const dotClass = 'fill-[#6366f1]' // custom color like indigo-400
const dotClass = 'fill-indigo-400'
// const pathClass = 'stroke-[#6366f1] stroke-2 z-1' // custom color like indigo-400
const pathClass = 'stroke-indigo-500 dark:stroke-indigo-400 stroke-2 z-1'
