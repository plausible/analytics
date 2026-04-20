import React, {
  ReactNode,
  useCallback,
  useEffect,
  useRef,
  useState
} from 'react'
import * as d3 from 'd3'
import classNames from 'classnames'

const IDEAL_Y_TICK_COUNT = 5
const MAX_X_TICK_COUNT = 8

type GraphYValues = ReadonlyArray<number | null>

/**
 * To ensure the effect to redraw the chart only runs when needed,
 * make sure these props don't change on every render of the parent.
 */
type GraphProps<
  T extends GraphYValues,
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
  onPointerEnter: (event: unknown) => void
  onPointerMove: PointerHandler<T>
  onPointerLeave: (event: unknown) => void
  onGotPointerCapture: (event: unknown) => void
  onClick?: PointerHandler<T>
  yFormat: (domainValue: d3.NumberValue, index: number) => string
  /**
   * Things are drawn in the order of settings,
   * so if one series needs to be drawn on top of the other,
   * it has to be after the other in the settings array.
   */
  settings: U
  gradients: {
    id: string
    stopTop: { color: string; opacity: number }
    stopBottom: { color: string; opacity: number }
  }[]
  children?: ReactNode
  highlightedIndex?: number | null
}

/**
 * Usage:
 * By setting `T` to `Readonly<[number | null, number | null, number | null]>>`
 * the graph is configured to draw 3 series.
 */
export function Graph<T extends GraphYValues>({
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

function InnerGraph<T extends GraphYValues>({
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
  onGotPointerCapture,
  onPointerEnter,
  onClick,
  yFormat,
  settings,
  gradients,
  highlightedIndex
}: GraphProps<T>) {
  const [extraMarginLeft, setExtraMarginLeft] = useState(0)

  const marginLeft = defaultMarginLeft + extraMarginLeft
  const xLeftEdge = marginLeft
  const xRightEdge = width - marginRight
  const yTopEdge = marginTop
  const yBottomEdge = height - marginBottom

  const svgRef = useRef<SVGSVGElement | null>(null)
  const pointsRef = useRef<Point<T>[] | null>(null)

  // Effect to fully redraw chart from scratch
  useEffect(() => {
    if (!svgRef.current) {
      return
    }
    const svgBoundingClientRect = svgRef.current.getBoundingClientRect()
    const minClientX = svgBoundingClientRect.left
    const maxClientX = svgBoundingClientRect.right

    // Declare the y (vertical position) scale.
    const y = getYScale({ yMax, yBottomEdge, yTopEdge })

    const optimalYTickValues = getOptimalYTickValues(y, yMax)

    const svg = d3.select(svgRef.current)

    const cleanup = () => {
      pointsRef.current = null
      svg.selectAll('*').remove()
    }

    // Hide svg until ready
    svg.attr('opacity', 0)
    const { textOffset } = fitYAxis({
      buildAxis: () =>
        svg
          .append('g')
          .attr('class', 'y-axis--container')
          .attr('transform', `translate(${xLeftEdge}, 0)`)
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
              .attr(
                'x2',
                getChartAreaWidth({
                  width,
                  marginLeft,
                  marginRight
                })
              )
              .attr('class', yTickLineClass)
          ),
      minClientX
    })
    const adjustmentIncrement = 4
    if (textOffset < 0) {
      const adjustmentSteps = Math.ceil(-textOffset / adjustmentIncrement)
      setExtraMarginLeft((curr) => curr + adjustmentSteps * adjustmentIncrement)
      return cleanup
    } else if (extraMarginLeft !== 0 && textOffset > 1 * adjustmentIncrement) {
      const adjustmentSteps = Math.floor(textOffset / adjustmentIncrement)
      setExtraMarginLeft((curr) =>
        Math.max(curr - adjustmentSteps * adjustmentIncrement, 0)
      )
      return cleanup
    }

    const bucketCount = data.length
    const x = getXScale({
      domain: getXDomain(bucketCount),
      xLeftEdge,
      xRightEdge
    })
    const suggestedXTickValues = getSuggestedXTickValues(x, bucketCount)

    // Add the x-axis
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
          .call(
            d3
              .axisBottom(x)
              .tickValues(xTickValues)
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

    const points: Point<T>[] = []
    for (const [seriesIndex, series] of settings.entries()) {
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

      for (const [i, d] of data.entries()) {
        const point =
          points[i] ?? getPoint({ index: i, datum: d, xScale: x, yScale: y })
        const dotForSeries = drawDot({
          svg,
          series,
          x: point.x,
          y: point.values[seriesIndex]
        })
        points[i] = {
          ...point,
          dots: [...point.dots, dotForSeries] as { [K in keyof T]: SelectedDot }
        }
      }
    }

    pointsRef.current = points

    // Unhide chart
    svg.attr('opacity', 1)

    return cleanup
  }, [
    data,
    gradients,
    height,
    marginRight,
    defaultMarginLeft,
    extraMarginLeft,
    marginTop,
    settings,
    width,
    yFormat,
    yMax,
    marginLeft,
    yBottomEdge,
    yTopEdge,
    xLeftEdge,
    xRightEdge
  ])

  const isInHoverableArea = useCallback(
    (xPointer: number, yPointer: number): boolean => {
      return (
        xPointer >= xLeftEdge - hoverBuffer &&
        xPointer <= xRightEdge + hoverBuffer &&
        yPointer >= yTopEdge - hoverBuffer &&
        // chart is interactive even over x-axis labels
        yPointer <= height
      )
    },
    [height, hoverBuffer, xLeftEdge, xRightEdge, yTopEdge]
  )

  useEffect(() => {
    const currentSvg = svgRef.current
    if (currentSvg && pointsRef.current) {
      const points = pointsRef.current
      const svg = d3.select(currentSvg)

      svg.on(
        'pointermove',
        (event) => {
          const { xPointer, yPointer } = getPosition(event)
          const inHoverableArea = isInHoverableArea(xPointer, yPointer)
          const closestIndexToPointer = inHoverableArea
            ? getClosestIndexToPointer(xPointer, points)
            : null
          onPointerMove({
            inHoverableArea,
            closestPoint:
              closestIndexToPointer !== null
                ? {
                    index: closestIndexToPointer,
                    x: points[closestIndexToPointer].x,
                    values: points[closestIndexToPointer].values
                  }
                : null,
            xPointer,
            yPointer,
            event
          })
        },
        { passive: true }
      )
      return () => {
        if (currentSvg) {
          const svg = d3.select(currentSvg)
          svg.on('pointermove', null)
        }
      }
    }
  }, [onPointerMove, isInHoverableArea, data])

  useEffect(() => {
    const currentSvg = svgRef.current
    if (currentSvg && pointsRef.current) {
      const svg = d3.select(currentSvg)
      svg.on(
        'gotpointercapture',
        (event) => {
          onGotPointerCapture(event)
        },
        { passive: true }
      )
    }
    return () => {
      if (currentSvg) {
        const svg = d3.select(currentSvg)
        svg.on('gotpointercapture', null)
      }
    }
  }, [onGotPointerCapture, isInHoverableArea, data])

  useEffect(() => {
    const currentSvg = svgRef.current
    if (currentSvg && pointsRef.current) {
      const svg = d3.select(currentSvg)
      svg.on(
        'pointerenter',
        (event) => {
          onPointerEnter(event)
        },
        { passive: true }
      )
    }
    return () => {
      if (currentSvg) {
        const svg = d3.select(currentSvg)
        svg.on('pointerenter', null)
      }
    }
  }, [onPointerEnter, isInHoverableArea, data])

  useEffect(() => {
    const currentSvg = svgRef.current
    if (currentSvg && pointsRef.current) {
      const svg = d3.select(currentSvg)
      svg.on(
        'lostpointercapture pointerleave',
        (event) => {
          onPointerLeave(event)
        },
        { passive: true }
      )
    }

    return () => {
      if (currentSvg) {
        const svg = d3.select(currentSvg)
        svg.on('lostpointercapture pointerleave', null)
      }
    }
  }, [onPointerLeave, isInHoverableArea, data])

  useEffect(() => {
    const currentSvg = svgRef.current
    if (currentSvg && pointsRef.current) {
      const svg = d3.select(currentSvg)
      const points = pointsRef.current
      if (typeof onClick !== 'function') {
        svg.on('click', null)
      } else {
        svg.on('click', (event) => {
          const { xPointer, yPointer } = getPosition(event)
          const inHoverableArea = isInHoverableArea(xPointer, yPointer)
          const closestIndexToPointer = inHoverableArea
            ? getClosestIndexToPointer(xPointer, points)
            : null
          onClick({
            inHoverableArea,
            closestPoint:
              closestIndexToPointer !== null
                ? {
                    index: closestIndexToPointer,
                    x: points[closestIndexToPointer].x,
                    values: points[closestIndexToPointer].values
                  }
                : null,
            xPointer,
            yPointer,
            event
          })
        })
      }
    }
    return () => {
      if (currentSvg) {
        const svg = d3.select(currentSvg)
        svg.on('click', null)
      }
    }
  }, [onClick, isInHoverableArea, data])

  useEffect(() => {
    pointsRef.current?.forEach(({ dots }, index) =>
      dots.forEach((g) =>
        g.attr(
          'data-active',
          highlightedIndex !== null && index === highlightedIndex ? '' : null
        )
      )
    )
  }, [highlightedIndex, data])

  return (
    <svg
      ref={svgRef}
      viewBox={`0 0 ${width} ${height}`}
      className={classNames('w-full h-auto', className)}
    />
  )
}

const yTickLineClass =
  'stroke-gray-150 dark:stroke-gray-800/75 group-first:stroke-gray-300 dark:group-first:stroke-gray-700'
const tickTextClass = 'fill-gray-500 dark:fill-gray-400 text-xs select-none'
const xTickLineClass = 'stroke-gray-300 dark:stroke-gray-700'

export const getXDomain = (bucketCount: number): [number, number] => {
  const xMin = 0
  const xMax = Math.max(bucketCount - 1, 1)
  return [xMin, xMax]
}

const getXScale = ({
  domain,
  xLeftEdge,
  xRightEdge
}: {
  domain: [number, number]
  xLeftEdge: number
  xRightEdge: number
}): d3.ScaleLinear<number, number, never> =>
  d3.scaleLinear(domain, [xLeftEdge, xRightEdge])

const getYScale = ({
  yMax,
  yBottomEdge,
  yTopEdge
}: {
  yMax: number
  yBottomEdge: number
  yTopEdge: number
}): d3.ScaleLinear<number, number, never> =>
  d3.scaleLinear([0, yMax], [yBottomEdge, yTopEdge]).nice(IDEAL_Y_TICK_COUNT)

const fitXAxis = ({
  buildAxis,
  suggestedXTickValues,
  minClientX,
  maxClientX
}: {
  xAxisSelection: d3.Selection<SVGGElement, unknown, null, undefined>
  buildAxis: (
    xTickValues: number[]
  ) => d3.Selection<SVGGElement, unknown, null, undefined>
  suggestedXTickValues: number[][]
  minClientX: number
  maxClientX: number
}) => {
  for (const [index, xTickValues] of suggestedXTickValues.entries()) {
    const isLastAttempt = index === suggestedXTickValues.length - 1
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

    if (overlapCount > 0 && !isLastAttempt) {
      axis.remove()
    } else {
      break
    }
  }
}

const fitYAxis = ({
  buildAxis,
  minClientX
}: {
  buildAxis: () => d3.Selection<SVGGElement, unknown, null, undefined>
  minClientX: number
}): { textOffset: number } => {
  let leftMostYTickText: number | null = null

  buildAxis().call((g) =>
    g.selectAll('.tick').each(function () {
      const rect = (this as SVGGraphicsElement).getBoundingClientRect()
      if (leftMostYTickText === null || rect.left < leftMostYTickText)
        leftMostYTickText = rect.left
    })
  )
  return leftMostYTickText !== null
    ? { textOffset: leftMostYTickText - minClientX }
    : { textOffset: 0 }
}

export const getSuggestedXTickValues = (
  scale: d3.ScaleLinear<number, number>,
  bucketCount: number
): number[][] => {
  const maxXTicks = Math.min(bucketCount, MAX_X_TICK_COUNT)
  const minTicks = 1
  const result = new Set<string>()
  for (let tickCount = maxXTicks; tickCount >= minTicks; tickCount--) {
    const tickValues = scale.ticks(tickCount)
    if (tickValues.every(isWholeNumber)) {
      // needs serialization to be comparable for uniqueness in Set
      const serializedArray = JSON.stringify(tickValues)
      result.add(serializedArray)
    }
  }

  return [...result].map((serializedArray) => JSON.parse(serializedArray))
}

const areIdealYTickValues = (tickValues: number[], yMax: number) =>
  Math.max(...tickValues) >= yMax && tickValues.every(isWholeNumber)

const getOptimalYTickValues = (
  scale: d3.ScaleLinear<number, number>,
  yMax: number
) => {
  const maxYTicks = IDEAL_Y_TICK_COUNT
  const minTicks = 1
  const suggested: number[][] = []
  for (let tickCount = maxYTicks; tickCount >= minTicks; tickCount--) {
    const tickValues = scale.ticks(tickCount)
    suggested.push(tickValues)
  }
  return (
    suggested.find((tickValues) => areIdealYTickValues(tickValues, yMax)) ??
    suggested[0]
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
  const textContent = elem.textContent
  // empty texts can't overlap
  if (!textContent?.length) {
    return { isOverlappingPrevious: false, rightEdge: lastTickTextRightEdge }
  }
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
}): void => {
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
}

function drawAreaUnderLine<T extends GraphYValues>({
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

function drawLine<T extends GraphYValues>({
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

function drawDot({
  svg,
  series,
  x,
  y
}: {
  svg: SelectedSVG
  series: SeriesConfig
  x: number
  y: number | null
}): SelectedDot {
  const group = svg.append('g').attr('class', 'group')
  if (series.dot && y !== null) {
    group
      .append('circle')
      .attr('r', 2.5)
      .attr('class', series.dot.dotClassName)
      .attr('transform', `translate(${x},${y})`)
  }
  return group
}

function getPoint<T extends GraphYValues>({
  index,
  datum,
  xScale,
  yScale
}: {
  index: number
  datum: Datum<T>
  xScale: d3.ScaleLinear<number, number, never>
  yScale: d3.ScaleLinear<number, number, never>
}): Point<T> {
  return {
    x: xScale(index),
    values: datum.values.map((v): number | null =>
      v !== null ? yScale(v) : null
    ) as unknown as T,
    dots: [] as Point<T>['dots']
  }
}

function getClosestIndexToPointer<T extends GraphYValues>(
  xPointer: number,
  points: Point<T>[]
): number {
  return d3.bisector(({ x }: Point<T>) => x).center(points, xPointer)
}

const getPosition = (
  event: unknown
): { xPointer: number; yPointer: number } => {
  const [[xPointer, yPointer]] = d3.pointers(event)
  return { xPointer, yPointer }
}

const isWholeNumber = (v: number) => v % 1 === 0

export type Datum<T extends GraphYValues> = {
  values: T
  xLabel: string
}

type XPos = number
type Point<T extends GraphYValues> = {
  x: XPos
  values: T
  dots: { [K in keyof T]: SelectedDot }
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

export type PointerHandler<T extends GraphYValues> = (opts: {
  inHoverableArea: boolean
  xPointer: number
  yPointer: number
  closestPoint: ({ index: number } & Pick<Point<T>, 'x' | 'values'>) | null
  event: unknown
}) => void

type SelectedSVG = d3.Selection<SVGSVGElement, unknown, null, undefined>
type SelectedDot = d3.Selection<SVGGElement, unknown, null, undefined>
