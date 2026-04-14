import React, { ReactNode, useEffect, useRef } from 'react'
import * as d3 from 'd3'
import classNames from 'classnames'

export type Datum<T extends ReadonlyArray<number | null>> = {
  values: T
  xLabel: string
}

type XPos = number
type Point<T extends ReadonlyArray<number | null>> = {
  x: XPos
  values: T
  dots: SelectedDots
}

export type SeriesConfig = {
  /** a single series can be drawn with multiple lines, like a solid line for some parts and a dashed line for other parts */
  lines?: {
    lineClassName: string
    startIndexInclusive?: number
    stopIndexExclusive?: number
  }[]
  underline?: { gradientId: string }
  dot?: { dotClassName: string }
}

export type PointerHandler = (opts: {
  inHoverableArea: boolean
  x: number
  y: number
  closestIndex: number | null
  event: unknown
}) => void

type GraphProps<
  T extends ReadonlyArray<number | null>,
  U = { [K in keyof T]: SeriesConfig }
> = {
  className: string
  width: number
  height: number
  /** pixels off the chart area that data is still hovered */
  hoverBuffer: number
  marginTop: number
  marginRight: number
  marginBottom: number
  /** initial guess for left margin, automatically enlarged to fit y tick texts */
  defaultMarginLeft: number
  data: Datum<T>[]
  yMax: number
  onPointerMove: PointerHandler
  onPointerLeave: () => void
  onClick?: () => void
  yFormat: (domainValue: d3.NumberValue, index: number) => string
  settings: U
  gradients: {
    id: string
    stopTop: { color: string; opacity: number }
    stopBottom: { color: string; opacity: number }
  }[]
  children?: ReactNode
}

export function Graph<T extends ReadonlyArray<number | null>>({
  children,
  ...rest
}: GraphProps<T>) {
  const { height, width } = rest
  return (
    <div
      className="relative flex justify-center items-center w-full"
      style={{ height: height, maxWidth: width }}
    >
      <InnerGraph {...rest} />
      {children}
    </div>
  )
}

function InnerGraph<T extends ReadonlyArray<number | null>>({
  className,
  width,
  height,
  hoverBuffer,
  marginBottom,
  marginTop,
  defaultMarginLeft,
  marginRight,
  data,
  yMax,
  onPointerMove,
  onPointerLeave,
  onClick,
  yFormat,
  settings,
  gradients
}: GraphProps<T>) {
  const svgRef = useRef<SVGSVGElement | null>(null)
  useEffect(() => {
    if (!svgRef.current) {
      return
    }
    console.log('effect running')
    const svgBoundingClientRect = svgRef.current.getBoundingClientRect()
    const minClientX = svgBoundingClientRect.left
    const maxClientX = svgBoundingClientRect.right

    let marginLeft = defaultMarginLeft
    let chartAreaWidth = getChartAreaWidth({
      width,
      marginLeft,
      marginRight
    })

    // Declare the y (vertical position) scale.
    const {
      scale: y,
      yBottomEdge,
      yTopEdge
    } = getYScale({ yMax, height, marginTop, marginBottom })
    const optimalYTickValues = getOptimalYTickValues(y, yMax)

    // select the svg container, hide it until ready
    const svg = d3.select(svgRef.current).attr('opacity', 0)

    ;({ marginLeft, chartAreaWidth } = fitYAxis({
      buildAxis: (marginLeft, chartAreaWidth) =>
        svg
          .append('g')
          .attr('opacity', 0)
          .attr('class', 'y-axis--container')
          .attr('transform', `translate(${marginLeft}, 0)`)
          .call(
            d3
              .axisLeft(y)
              .tickFormat(yFormat)
              .tickSize(0)
              .tickValues(optimalYTickValues)
          )
          .call((g) => g.select('.domain').remove())
          .call((g) => g.selectAll('.tick').attr('class', 'tick group'))
          .call((g) => g.selectAll('.tick text').attr('class', tickTextClass))
          .call((g) =>
            g
              .selectAll('.tick line')
              .clone()
              .attr('x2', chartAreaWidth)
              .attr('class', yTickLineClass)
          ),
      marginLeft,
      chartAreaWidth,
      width,
      marginRight,
      minClientX
    }))
    const xMax = Math.max(data.length - 1, 1)
    const {
      scale: x,
      xLeftEdge,
      xRightEdge
    } = getXScale({ xMax, width, marginLeft, marginRight })
    const suggestedXTickValues = getSuggestedXTickValues(x, data.length)

    // add the x-axis
    const xAxisSelection = svg
      .append('g')
      .attr('class', 'x-axis--container')
      .attr('transform', `translate(0,${yBottomEdge})`)

    fitXAxis({
      xAxisSelection,
      buildAxis: (xTickValues) =>
        xAxisSelection
          .append('g')
          .attr('class', 'x-axis')
          .attr('opacity', 0)
          .call(
            d3
              .axisBottom(x)
              .tickValues(JSON.parse(xTickValues) as Array<number>)
              .tickSize(4)
              .tickFormat(getXTickFormat(data))
          )
          .call((g) => g.select('.domain').remove())
          .call((g) => g.selectAll('.tick').attr('class', 'tick group'))
          .call((g) =>
            g.selectAll('.tick line').attr('class', classNames(xTickLineClass))
          )
          .call((g) =>
            g
              .selectAll('.tick text')
              .attr('class', classNames(tickTextClass, 'translate-y-2'))
          ),
      suggestedXTickValues,
      minClientX,
      maxClientX
    })

    for (const gradient of gradients) {
      addGradient({
        svg,
        id: gradient.id,
        stopTop: gradient.stopTop,
        stopBottom: gradient.stopBottom
      })
    }

    const points: Point<T>[] = data.map((d, index) => {
      const xValue = x(index)
      const yValues: T = d.values.map((v) =>
        v !== null ? y(v) : null
      ) as unknown as T
      const dots = drawDots({ svg, settings, x: xValue, yValues })
      return {
        x: xValue,
        values: yValues,
        dots
      }
    })

    for (const [seriesIndex, series] of settings.entries()) {
      if (series.lines) {
        for (const line of series.lines) {
          drawLine({
            svg,
            datum: data,
            isDefined: (d, i) => {
              const valueDefined = d.values[seriesIndex] !== null
              const atOrOverStart =
                line.startIndexInclusive !== undefined
                  ? i >= line.startIndexInclusive
                  : true
              const beforeEnd =
                line.stopIndexExclusive !== undefined
                  ? i < line.stopIndexExclusive
                  : true
              return valueDefined && atOrOverStart && beforeEnd
            },
            xAccessor: (_d, index) => x(index),
            yAccessor: (d) => y(d.values[seriesIndex]!),
            className: line.lineClassName
          })
        }
      }

      if (series.underline) {
        drawAreaUnderLine({
          svg,
          gradientId: series.underline.gradientId,
          datum: data,
          isDefined: (d) => d.values[seriesIndex] !== null,
          xAccessor: (_d, index) => x(index),
          y0Accessor: yBottomEdge,
          y1Accessor: (d) => y(d.values[seriesIndex]!)
        })
      }
    }

    const getPosition = (
      event: unknown
    ): { xPointer: number; yPointer: number; inHoverableArea: boolean } => {
      const [[xPointer, yPointer]] = d3.pointers(event)

      const inHoverableArea =
        xPointer >= xLeftEdge - hoverBuffer &&
        xPointer <= xRightEdge + hoverBuffer &&
        yPointer >= yTopEdge - hoverBuffer &&
        // chart is interactive even over x-axis labels
        yPointer <= height
      return { xPointer, yPointer, inHoverableArea }
    }
    const getClosestIndexToPointer = (xPointer: number): number =>
      d3.bisector(({ x }: Point<T>) => x).center(points, xPointer)

    const handleDotsForClosestIndex = (closestIndexToPointer: number | null) =>
      points.forEach(({ dots }, index) =>
        dots.attr(
          'data-active',
          closestIndexToPointer !== null && index === closestIndexToPointer
            ? ''
            : null
        )
      )

    svg
      .on(
        'pointermove',
        (event) => {
          if (typeof onPointerMove !== 'function') {
            return
          }
          const { xPointer, yPointer, inHoverableArea } = getPosition(event)
          const closestIndexToPointer = inHoverableArea
            ? getClosestIndexToPointer(xPointer)
            : null
          handleDotsForClosestIndex(closestIndexToPointer)
          onPointerMove({
            inHoverableArea: true,
            closestIndex: closestIndexToPointer,
            x: xPointer,
            y: yPointer,
            event
          })
        },
        { passive: true }
      )
      .on(
        'lostpointercapture pointerleave',
        () => {
          handleDotsForClosestIndex(null)
          onPointerLeave()
        },
        { passive: true }
      )
      .attr('opacity', 1)

    return () => {
      svg.selectAll('*').remove()
    }
  }, [
    data,
    gradients,
    onPointerLeave,
    onPointerMove,
    settings,
    width,
    height,
    marginBottom,
    marginTop,
    defaultMarginLeft,
    marginRight,
    hoverBuffer,
    yFormat,
    yMax
  ])

  return (
    <svg
      onClick={onClick}
      onPointerUp={(e) => {
        if (e.pointerType === 'touch' && typeof onClick === 'function') {
          onClick()
        }
      }}
      ref={svgRef}
      viewBox={`0 0 ${width} ${height}`}
      className={classNames('w-full h-auto [touch-action:pan-y]', className)}
    />
  )
}

const yTickLineClass =
  'stroke-gray-150 dark:stroke-gray-800/75 group-first:stroke-gray-300 dark:group-first:stroke-gray-700'
const tickTextClass = 'fill-gray-500 dark:fill-gray-400 text-xs select-none'
const xTickLineClass = 'stroke-gray-300 dark:stroke-gray-700'

const getXScale = ({
  xMax,
  width,
  marginLeft,
  marginRight
}: {
  xMax: number
  width: number
  marginLeft: number
  marginRight: number
}) => {
  const xLeftEdge = marginLeft
  const xRightEdge = width - marginRight
  const scale = d3.scaleLinear([0, xMax], [xLeftEdge, xRightEdge])
  return { scale, xLeftEdge, xRightEdge }
}

const getYScale = ({
  yMax,
  height,
  marginTop,
  marginBottom
}: {
  yMax: number
  height: number
  marginTop: number
  marginBottom: number
}) => {
  const yBottomEdge = height - marginBottom
  const yTopEdge = marginTop
  const scale = d3.scaleLinear([0, yMax], [yBottomEdge, yTopEdge]).nice(5)
  return { scale, yBottomEdge, yTopEdge }
}

const fitXAxis = ({
  xAxisSelection,
  buildAxis,
  suggestedXTickValues,
  minClientX,
  maxClientX
}: {
  xAxisSelection: d3.Selection<SVGGElement, unknown, null, undefined>
  buildAxis: (
    xTickValues: string
  ) => d3.Selection<SVGGElement, unknown, null, undefined>
  suggestedXTickValues: Set<string>
  minClientX: number
  maxClientX: number
}) => {
  for (const [index, xTickValues] of [...suggestedXTickValues].entries()) {
    const axis = buildAxis(xTickValues)

    let overlapCount = 0
    let lastTickTextRightEdge = 0
    axis.call((g) =>
      g.selectAll('.tick text').each(function (_, i, groups) {
        const { isOverlappingPrevious, rightEdge } = handleXTickText({
          elem: this as SVGGraphicsElement,
          position:
            i === 0 ? 'first' : i === groups.length - 1 ? 'last' : 'neither',
          minClientX,
          maxClientX,
          lastTickTextRightEdge
        })
        if (isOverlappingPrevious) {
          overlapCount++
        }
        lastTickTextRightEdge = rightEdge
      })
    )

    if (overlapCount > 0 && index !== suggestedXTickValues.size - 1) {
      axis.remove()
    } else {
      break
    }
  }
  xAxisSelection.call((g) => g.select('.x-axis').attr('opacity', 1))
}

const fitYAxis = ({
  buildAxis,
  marginLeft: initialMarginLeft,
  chartAreaWidth: initialChartAreaWidth,
  width,
  marginRight,
  minClientX,
  maxAttempts = 2
}: {
  buildAxis: (
    marginLeft: number,
    chartAreaWidth: number
  ) => d3.Selection<SVGGElement, unknown, null, undefined>
  marginLeft: number
  chartAreaWidth: number
  width: number
  marginRight: number
  minClientX: number
  maxAttempts?: number
}): { marginLeft: number; chartAreaWidth: number } => {
  let marginLeft = initialMarginLeft
  let chartAreaWidth = initialChartAreaWidth

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    let leftMostYTickText: number | null = null

    const yAxis = buildAxis(marginLeft, chartAreaWidth).call((g) =>
      g.selectAll('.tick').each(function () {
        const rect = (this as SVGGraphicsElement).getBoundingClientRect()
        if (leftMostYTickText === null || rect.left < leftMostYTickText)
          leftMostYTickText = rect.left
      })
    )

    if (leftMostYTickText !== null) {
      const isLastAttempt = attempt === maxAttempts
      const textOffset = leftMostYTickText - minClientX
      if (textOffset < 0 && !isLastAttempt) {
        yAxis.remove()
        marginLeft += Math.ceil(-textOffset / 4) * 4
        chartAreaWidth = getChartAreaWidth({ width, marginLeft, marginRight })
        continue
      }
      yAxis.attr('opacity', null)
    }
    break
  }

  return { marginLeft, chartAreaWidth }
}

const getSuggestedXTickValues = (
  scale: d3.ScaleLinear<number, number>,
  bucketCount: number
): Set<string> => {
  const maxXTicks = Math.min(bucketCount, 8)
  const result = new Set<string>()
  new Array(maxXTicks).fill(null).forEach((_v, i) => {
    const tickValues = scale.ticks(maxXTicks - i)
    if (tickValues.every(isWholeNumber)) {
      result.add(JSON.stringify(tickValues))
    }
  })
  return result
}

const getOptimalYTickValues = (
  scale: d3.ScaleLinear<number, number>,
  yMax: number
) => {
  const suggested = [5, 4, 3, 2, 1].map((i) => scale.ticks(i))
  return (
    suggested.find(
      (values) => Math.max(...values) >= yMax && values.every(isWholeNumber)
    ) ?? suggested[0]
  )
}

const handleXTickText = ({
  elem,
  position,
  minClientX,
  maxClientX,
  lastTickTextRightEdge
}: {
  elem: SVGGraphicsElement
  position: 'first' | 'last' | 'neither'
  minClientX: number
  maxClientX: number
  lastTickTextRightEdge: number
}): { isOverlappingPrevious: boolean; rightEdge: number } => {
  let textRect = elem.getBoundingClientRect()

  if (position === 'first') {
    const distanceFromAxisEdge = textRect.left - minClientX
    if (distanceFromAxisEdge < 0) {
      d3.select(elem).attr('dx', -distanceFromAxisEdge)
      textRect = elem.getBoundingClientRect()
    }
  }

  if (position === 'last') {
    const distanceFromAxisEdge = maxClientX - textRect.right
    if (distanceFromAxisEdge < 0) {
      d3.select(elem).attr('dx', distanceFromAxisEdge)
      textRect = elem.getBoundingClientRect()
    }
  }

  return {
    isOverlappingPrevious: textRect.left < lastTickTextRightEdge,
    rightEdge: textRect.right
  }
}

const getXTickFormat =
  <T extends { xLabel: string }>(data: T[]) =>
  (bucketIndex: d3.NumberValue) => {
    // for low tick counts, it may try to render ticks
    // with the value 0.5, 1.5, etc that don't have data defined
    const datum = data[bucketIndex.valueOf()]
    if (!datum) return ''
    return datum.xLabel
  }

const getChartAreaWidth = ({
  width,
  marginLeft,
  marginRight
}: {
  width: number
  marginLeft: number
  marginRight: number
}) => width - marginLeft - marginRight

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

function drawAreaUnderLine<T extends ReadonlyArray<number | null>>({
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
  isDefined: (d: Datum<T>, index: number) => boolean
  xAccessor: (d: Datum<T>, index: number) => number
  y0Accessor: number
  y1Accessor: (d: Datum<T>, index: number) => number
  datum: Datum<T>[]
}) {
  const area = d3
    .area<Datum<T>>()
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

function drawLine<T extends ReadonlyArray<number | null>>({
  svg,
  datum,
  isDefined,
  xAccessor,
  yAccessor,
  className
}: {
  svg: SelectedSVG
  datum: Datum<T>[]
  isDefined: (d: Datum<T>, index: number) => boolean
  xAccessor: (d: Datum<T>, index: number) => number
  yAccessor: (d: Datum<T>, index: number) => number
  className?: string
}) {
  const line = d3.line<Datum<T>>().defined(isDefined).x(xAccessor).y(yAccessor)

  svg
    .append('path')
    .attr('class', classNames(className))
    .datum(datum)
    .attr('d', line)
}

function drawDots<T extends ReadonlyArray<number | null>>({
  svg,
  settings,
  x,
  yValues
}: {
  svg: SelectedSVG
  settings: { [K in keyof T]: SeriesConfig }
  x: number
  yValues: T
}): SelectedDots {
  const dotsForX = svg.append('g').attr('class', 'group')
  for (const [seriesIndex, series] of settings.entries()) {
    if (series.dot && yValues[seriesIndex] !== null) {
      dotsForX
        .append('circle')
        .attr('r', 2.5)
        .attr('class', series.dot.dotClassName)
        .attr('transform', `translate(${x},${yValues[seriesIndex]})`)
    }
  }

  return dotsForX
}

const isWholeNumber = (v: number) => v % 1 === 0

type SelectedSVG = d3.Selection<SVGSVGElement, unknown, null, undefined>
type SelectedDots = d3.Selection<SVGGElement, unknown, null, undefined>
