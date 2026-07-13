import React, {
  ReactNode,
  RefObject,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState
} from 'react'
import { UIMode, useTheme } from '../../theme-context'
import { MetricFormatterShort } from '../reports/metric-formatter'
import { DashboardPeriod } from '../../dashboard-time-periods'
import {
  formatMonthYYYY,
  formatDayShort,
  formatTime,
  is12HourClock,
  parseNaiveDate,
  formatDay,
  isThisYear
} from '../../util/date'
import classNames from 'classnames'
import { ChangeArrow } from '../reports/change-arrow'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { Graph, PointerHandler, SeriesConfig } from '../../components/graph'
import { useSiteContext, PlausibleSite } from '../../site-context'
import { GraphTooltipWrapper } from '../../components/graph-tooltip'
import { MetricValue, RevenueMetricValue } from '../../api'
import { MainGraphResponse } from './fetch-main-graph'
import {
  remapAndFillData,
  getLineSegments,
  GraphDatum,
  METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS,
  getChangeInPercentagePoints,
  getRelativeChange,
  REVENUE_METRICS,
  getFirstAndLastTimeLabels,
  MainGraphSeriesName
} from './main-graph-data'
import { Metric, getMetricLabel } from '../metrics'
import { extractIntervalFromDimensions, Interval } from './intervals'
import { useRoutelessModalsContext } from '../../navigation/routeless-modals-context'
import {
  Annotation,
  AnnotationType,
  canShowAddAnnotationButton,
  getAnnotationGranularity,
  groupAnnotationsByTimeLabel
} from '../../annotations/annotations'
import { useUserContext } from '../../user-context'
import { Button } from '../../components/button'
import { HoverAnnotationsList } from '../../annotations/hover-annotations-list'
import { InteractiveAnnotationsList } from '../../annotations/interactive-annotations-list'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const defaultMarginLeft = 16 // this is adjusted by the Graph component based on y-axis label width
const hoverBuffer = 4
const HORIZONTAL_PAN_DELAY_MS = 100

type MainGraphYValues = Readonly<
  [
    // first element is comparison series
    number | null,
    // second element is main series
    number | null
  ]
>

type TooltipState = {
  x: number
  selectedIndex: number | null
  persistent: boolean
}

const initialTooltipState: TooltipState = {
  x: 0,
  selectedIndex: null,
  persistent: false
}

export const MainGraph = ({
  width,
  data,
  annotations
}: {
  width: number
  data: MainGraphResponse
  annotations: Annotation[]
}) => {
  const site = useSiteContext()
  const user = useUserContext()
  const { mode } = useTheme()
  const navigate = useAppNavigate()
  const { primaryGradient, secondaryGradient } = paletteByTheme[mode]
  const [isTouchDevice, setIsTouchDevice] = useState<null | boolean>(null)
  const [tooltip, setTooltip] = useState<TooltipState>(initialTooltipState)
  const canAddAnnotation = canShowAddAnnotationButton({
    user,
    siteAnnotationsAvailable: site.siteAnnotationsAvailable
  })

  const closeTooltip = useCallback(() => {
    setTooltip(initialTooltipState)
  }, [])

  useEffect(() => {
    setTooltip(initialTooltipState)
  }, [width])

  const tooltipRef = useRef<HTMLDivElement>(null)
  const { selectedIndex } = tooltip
  const panGestureStartTimeRef = useRef<number | null>(null)
  const metric = data.query.metrics[0] as Metric
  const interval = extractIntervalFromDimensions(data.query.dimensions)
  const isRealtime = data.extraContext.isRealtime

  const annotationsByTimeLabel = useMemo(
    () => groupAnnotationsByTimeLabel(annotations, interval),
    [annotations, interval]
  )

  useEffect(() => {
    setTooltip(initialTooltipState)
  }, [data])

  useEffect(() => {
    const onClickOutside = (event: MouseEvent) => {
      if (!tooltipRef.current?.contains(event.target as Node)) {
        setTooltip(initialTooltipState)
      }
    }
    if (tooltip.persistent && isTouchDevice === false) {
      document.addEventListener('click', onClickOutside)
    }
    return () => {
      document.removeEventListener('click', onClickOutside)
    }
  }, [tooltip.persistent, isTouchDevice])

  useEffect(() => {
    const onPointerCancel = (event: PointerEvent) => {
      if (event.pointerType === 'touch') {
        panGestureStartTimeRef.current = null
        if (tooltipRef.current?.contains(event.target as Node)) {
          return
        }
        setTooltip(initialTooltipState)
      }
    }
    document.addEventListener('pointercancel', onPointerCancel)
    return () => document.removeEventListener('pointercancel', onPointerCancel)
  }, [])

  const {
    remappedData,
    yMax,
    dateIsUnambiguous,
    yearIsUnambiguous,
    mainPeriodLengthInDays,
    mainPeriodLengthInMonths,
    settings,
    remappedDataInGraphFormat,
    gradients
  } = useMemo(() => {
    const mainSeriesStartEndLabels = getFirstAndLastTimeLabels(
      data,
      MainGraphSeriesName.main
    )
    const comparisonSeriesStartEndLabels = getFirstAndLastTimeLabels(
      data,
      MainGraphSeriesName.comparison
    )
    const remappedData = remapAndFillData({
      getValue: (item) => item.metrics[0],
      getNumericValue: REVENUE_METRICS.includes(metric)
        ? (v) => (v as RevenueMetricValue).value
        : (v) => ((v as number | null) === null ? 0 : (v as number)),
      getChange: METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS.includes(metric)
        ? getChangeInPercentagePoints
        : getRelativeChange,
      data
    })

    let yMax = 1

    // can't be done in a single pass with remapAndFillData
    // because we need the xLabels formatting parameters to be known
    const remappedDataInGraphFormat = remappedData.map(
      ({ main, comparison }, bucketIndex) => {
        const dataPoint = {
          values: [
            comparison.isDefined ? comparison.numericValue : null,
            main.isDefined ? main.numericValue : null
          ] as const,
          xLabel: main.isDefined
            ? getBucketLabel(main.timeLabel, {
                shouldShowDate: !isDateUnambiguous({
                  startEndLabels: mainSeriesStartEndLabels
                }),
                shouldShowYear: !isYearUnambiguous({
                  site,
                  startEndLabels: mainSeriesStartEndLabels
                }),
                interval,
                isRealtime,
                bucketIndex,
                totalBuckets: remappedData.length
              })
            : ''
        }
        if (main.isDefined && main.numericValue > yMax) {
          yMax = main.numericValue
        }
        if (comparison.isDefined && comparison.numericValue > yMax) {
          yMax = comparison.numericValue
        }
        return dataPoint
      }
    )

    const gradients = [primaryGradient, secondaryGradient]
    const mainLineSegments = getLineSegments(remappedData.map((d) => d.main))
    const comparisonLineSegments = getLineSegments(
      remappedData.map((d) => d.comparison)
    )

    const mainSeries: SeriesConfig = {
      lines: mainLineSegments.map(({ type, ...rest }) => ({
        lineClassName: classNames(
          sharedPathClass,
          mainPathClass,
          { current: dashedPathClass, full: roundedPathClass }[type]
        ),
        ...rest
      })),
      underline: { gradientId: primaryGradient.id },
      dot: { dotClassName: classNames(sharedDotClass, mainDotClass) }
    }

    const comparisonSeries: SeriesConfig = {
      lines: comparisonLineSegments.map(({ type, ...rest }) => ({
        lineClassName: classNames(
          sharedPathClass,
          comparisonPathClass,
          roundedPathClass
        ),
        ...rest
      })),
      underline: { gradientId: secondaryGradient.id },
      dot: { dotClassName: classNames(sharedDotClass, comparisonDotClass) }
    }

    const settings: [SeriesConfig, SeriesConfig] = [
      comparisonSeries,
      mainSeries
    ]

    const yearIsUnambiguous = isYearUnambiguous({
      site,
      startEndLabels: [
        ...mainSeriesStartEndLabels,
        ...comparisonSeriesStartEndLabels
      ]
    })
    const dateIsUnambiguous = isDateUnambiguous({
      startEndLabels: [
        ...mainSeriesStartEndLabels,
        ...comparisonSeriesStartEndLabels
      ]
    })
    const mainPeriodStart = parseNaiveDate(data.query.date_range[0])
    const mainPeriodEnd = parseNaiveDate(data.query.date_range[1])
    const mainPeriodLengthInDays = mainPeriodEnd.diff(mainPeriodStart, 'days')
    const mainPeriodLengthInMonths = mainPeriodEnd
      .startOf('month')
      .diff(mainPeriodStart.startOf('month'), 'months')

    return {
      remappedData,
      remappedDataInGraphFormat,
      yMax,
      dateIsUnambiguous,
      yearIsUnambiguous,
      mainPeriodLengthInDays,
      mainPeriodLengthInMonths,
      settings,
      gradients
    }
  }, [
    site,
    data,
    interval,
    isRealtime,
    primaryGradient,
    secondaryGradient,
    metric
  ])

  const annotationsByIndex = useMemo(
    () =>
      remappedData.map((datum) => {
        const annotationsOnDatum = datum.main.isDefined
          ? (annotationsByTimeLabel[datum.main.timeLabel] ?? [])
          : []
        return {
          count: annotationsOnDatum.length
        }
      }),
    [remappedData, annotationsByTimeLabel]
  )

  const getFormattedValue = useCallback(
    (value: MetricValue) => MetricFormatterShort[metric](value),
    [metric]
  )
  const yFormat = useCallback(
    (numericValue: d3.NumberValue) =>
      MetricFormatterShort[metric](numericValue),
    [metric]
  )

  const onPointerMove = useCallback<PointerHandler<MainGraphYValues>>(
    ({ inHoverableArea, closestPoint, event }) => {
      if (event instanceof PointerEvent && event.pointerType === 'touch') {
        setIsTouchDevice(true)
        if (tooltip.persistent && inHoverableArea && closestPoint) {
          const now = Date.now()
          // move the tooltip only when it is certain it's not a y-pan
          if (panGestureStartTimeRef.current === null) {
            panGestureStartTimeRef.current = now
          } else if (
            now - panGestureStartTimeRef.current >=
            HORIZONTAL_PAN_DELAY_MS
          ) {
            setTooltip({
              selectedIndex: closestPoint.index,
              x: closestPoint.x,
              persistent: true
            })
          }
        }
        return
      }
      setIsTouchDevice(false)
      setTooltip((currentState): TooltipState => {
        const currentlyPersistent = currentState.persistent
        if (currentlyPersistent) {
          return currentState
        }
        if (!inHoverableArea || !closestPoint) {
          return initialTooltipState
        }
        return {
          persistent: false,
          selectedIndex: closestPoint.index,
          x: closestPoint.x
        }
      })
    },
    [tooltip.persistent]
  )

  const onGotPointerCapture = useCallback((event: unknown) => {
    if (isTouchEvent(event)) {
      return setIsTouchDevice(true)
    }
  }, [])

  const onPointerEnter = useCallback((event: unknown) => {
    if (isTouchEvent(event)) {
      return setIsTouchDevice(true)
    }
  }, [])

  const onPointerLeave = useCallback(() => {
    panGestureStartTimeRef.current = null
    if (tooltip.persistent) {
      return
    }
    setTooltip(initialTooltipState)
  }, [tooltip.persistent])

  const showZoomToPeriod = canZoomToPeriod(
    interval,
    mainPeriodLengthInDays,
    mainPeriodLengthInMonths
  )
  const selectedDatum = selectedIndex !== null && remappedData[selectedIndex]

  const zoomDate =
    showZoomToPeriod && selectedDatum && selectedDatum.main.isDefined
      ? selectedDatum.main.timeLabel
      : null

  const annotationDatetime =
    selectedDatum && selectedDatum.main.isDefined
      ? selectedDatum.main.timeLabel
      : null

  const zoomToPeriod = useCallback(
    (date: string) => {
      setTooltip(initialTooltipState)
      navigate({
        search: (currentSearch) => ({
          ...currentSearch,
          date,
          period:
            interval === Interval.month
              ? DashboardPeriod.month
              : DashboardPeriod.day
        })
      })
    },
    [navigate, interval]
  )

  const onChartClick = useCallback<PointerHandler<MainGraphYValues>>(
    ({ inHoverableArea, closestPoint, event }) => {
      // the first tap / click can happen when
      // isTouchDevice isn't determined yet
      // (no preceding pointerenter, gotpointercapture, pointermove)
      const shouldHandleAsTouch = isTouchDevice ?? isTouchEvent(event)
      if (isTouchDevice === null) {
        setIsTouchDevice(shouldHandleAsTouch)
      }
      if (shouldHandleAsTouch) {
        if (inHoverableArea && closestPoint) {
          return setTooltip({
            selectedIndex: closestPoint.index,
            x: closestPoint.x,
            persistent: true
          })
        }
        return setTooltip(initialTooltipState)
      }

      if (tooltip.persistent) {
        return
      }
      if (typeof zoomDate === 'string') {
        return zoomToPeriod(zoomDate)
      }
    },
    [isTouchDevice, zoomDate, zoomToPeriod, tooltip.persistent]
  )

  const onContextMenu = useCallback<PointerHandler<MainGraphYValues>>(
    ({ event }) => {
      if (selectedDatum) {
        ;(event as Event).preventDefault()
        return setTooltip((current) => ({ ...current, persistent: true }))
      }
    },
    [selectedDatum]
  )

  return (
    <Graph<MainGraphYValues>
      className={classNames({
        'cursor-pointer': selectedDatum && showZoomToPeriod,
        'touch-pan-y': tooltip.persistent
      })}
      highlightedIndex={selectedIndex}
      width={width}
      height={height}
      hoverBuffer={hoverBuffer}
      marginTop={marginTop}
      marginRight={marginRight}
      marginBottom={marginBottom}
      defaultMarginLeft={defaultMarginLeft}
      settings={settings}
      data={remappedDataInGraphFormat}
      yMax={yMax}
      onPointerEnter={onPointerEnter}
      onGotPointerCapture={onGotPointerCapture}
      onPointerMove={onPointerMove}
      onPointerLeave={onPointerLeave}
      onClick={onChartClick}
      onContextMenu={onContextMenu}
      yFormat={yFormat}
      gradients={gradients}
      annotationsByIndex={annotationsByIndex}
    >
      {!!selectedDatum && isTouchDevice !== null && (
        <MainGraphTooltip
          getFormattedValue={getFormattedValue}
          maxX={width}
          showZoomToPeriod={!!zoomDate}
          shouldShowYear={!yearIsUnambiguous}
          shouldShowDate={!dateIsUnambiguous}
          isRealtime={isRealtime}
          hasConversionGoalFilter={data.extraContext.hasConversionGoalFilter}
          interval={interval}
          metric={metric}
          x={tooltip.x}
          datum={selectedDatum}
          bucketIndex={selectedIndex}
          totalBuckets={remappedData.length}
          persistent={tooltip.persistent}
          tooltipRef={tooltipRef}
          isTouchDevice={isTouchDevice}
        >
          {tooltip.persistent ? (
            <PersistentTooltipContents
              annotationDatetime={annotationDatetime}
              annotations={
                annotationDatetime
                  ? annotationsByTimeLabel[annotationDatetime]
                  : undefined
              }
              isTouchDevice={isTouchDevice}
              interval={interval}
              zoomDate={zoomDate}
              onZoomToPeriod={zoomToPeriod}
              canAddAnnotation={canAddAnnotation}
              closeTooltip={closeTooltip}
            />
          ) : (
            <HoveredTooltipContents
              annotations={
                annotationDatetime
                  ? annotationsByTimeLabel[annotationDatetime]
                  : undefined
              }
              interval={interval}
              zoomDate={zoomDate}
              canAddAnnotation={canAddAnnotation}
            />
          )}
        </MainGraphTooltip>
      )}
    </Graph>
  )
}

type TooltipContentsProps = {
  annotations: Annotation[] | undefined
  interval: Interval
  zoomDate: string | null
  canAddAnnotation: boolean
}

const PersistentTooltipContents = ({
  annotationDatetime,
  annotations,
  isTouchDevice,
  interval,
  zoomDate,
  onZoomToPeriod,
  canAddAnnotation,
  closeTooltip
}: {
  annotationDatetime: string | null
  isTouchDevice: boolean
  onZoomToPeriod: (date: string) => void
  closeTooltip: () => void
} & TooltipContentsProps) => {
  const { setModal } = useRoutelessModalsContext()

  const hasActions = !!zoomDate || (!!annotationDatetime && canAddAnnotation)
  return (
    <>
      {!!annotations?.length && (
        <InteractiveAnnotationsList
          annotations={annotations}
          isTouchDevice={isTouchDevice}
          closeTooltip={closeTooltip}
        />
      )}
      {hasActions && (
        <div className="flex flex-row gap-x-2 mt-2">
          {!!annotationDatetime && canAddAnnotation && (
            <Button
              size="xs"
              className="flex-1 bg-gray-600/70 border-gray-600/70 hover:bg-gray-600 hover:border-gray-600"
              onClick={() => {
                closeTooltip()
                setModal({
                  type: 'create-annotation',
                  annotation: {
                    type: AnnotationType.personal,
                    datetime: annotationDatetime,
                    granularity: getAnnotationGranularity(interval)
                  }
                })
              }}
            >
              Add note
            </Button>
          )}
          {!!zoomDate && (
            <Button
              size="xs"
              className="flex-1 bg-gray-600/70 border-gray-600/70 hover:bg-gray-600 hover:border-gray-600"
              onClick={() => onZoomToPeriod(zoomDate)}
            >{`View ${interval}`}</Button>
          )}
        </div>
      )}
    </>
  )
}

const HoveredTooltipContents = ({
  annotations,
  interval,
  zoomDate,
  canAddAnnotation
}: TooltipContentsProps) => {
  return (
    <>
      {!!annotations?.length && (
        <HoverAnnotationsList annotations={annotations} />
      )}
      <hr className="border-gray-600 dark:border-gray-800 my-1" />
      <div className="flex flex-col gap-y-0.5">
        {!!zoomDate && (
          <div className="text-gray-300 dark:text-gray-400 text-xs">
            {`Click to view ${interval}`}
          </div>
        )}
        <div className="text-gray-300 dark:text-gray-400 text-xs">
          {canAddAnnotation
            ? 'Right click for more actions'
            : 'Right click to pin tooltip'}
        </div>
      </div>
    </>
  )
}

const isTouchEvent = (event: unknown) =>
  event instanceof PointerEvent && event.pointerType === 'touch'

const mainGraphTooltipClassName =
  'absolute bg-gray-800 dark:bg-gray-950 py-3 px-4 rounded-md shadow shadow-gray-200 dark:shadow-gray-850 w-max max-w-[220px] sm:max-w-[300px]'

type MainGraphTooltipProps = {
  metric: Metric
  getFormattedValue: (value: MetricValue) => string
  interval: Interval
  isRealtime: boolean
  hasConversionGoalFilter: boolean
  shouldShowYear: boolean
  shouldShowDate: boolean
  x: number
  datum: GraphDatum
  showZoomToPeriod?: boolean
  bucketIndex: number
  totalBuckets: number
  maxX: number
  persistent: boolean
  onClick?: () => void
  children?: ReactNode
  tooltipRef: RefObject<HTMLDivElement>
  isTouchDevice: boolean
}

const MainGraphTooltip = ({
  metric,
  getFormattedValue,
  interval,
  hasConversionGoalFilter,
  isRealtime,
  shouldShowDate,
  shouldShowYear,
  maxX,
  x,
  datum,
  bucketIndex,
  totalBuckets,
  persistent,
  children,
  tooltipRef,
  isTouchDevice
}: MainGraphTooltipProps) => {
  const metricLabel = getMetricLabel(metric, {
    hasConversionGoalFilter
  })
  const { main, comparison, change } = datum
  return (
    <GraphTooltipWrapper
      wrapperRef={tooltipRef}
      horizontalAnchor="start"
      verticalAnchor="topEdge"
      x={x}
      y={0}
      minWidth={200}
      maxX={maxX}
      className={classNames(mainGraphTooltipClassName, {
        'select-none': !persistent || isTouchDevice,
        'pointer-events-none': !persistent
      })}
    >
      <aside
        className="text-sm font-normal text-gray-100 flex flex-col gap-2"
        data-testid="graph-tooltip"
      >
        <div className="flex justify-between items-center rounded-sm">
          <div
            data-testid="metric-label"
            className="font-semibold mr-4 text-xs uppercase whitespace-nowrap"
          >
            {metricLabel}
          </div>
          {comparison.isDefined && typeof change === 'number' && (
            <ChangeArrow
              className="text-xs/6 font-medium text-white whitespace-nowrap"
              metric={metric}
              change={change}
            />
          )}
        </div>
        <div className="flex flex-col">
          {main.isDefined && (
            <div className="flex flex-row justify-between items-center">
              <div className="flex items-center mr-4">
                <div className="size-2 flex-none mr-2 rounded-full bg-indigo-400" />
                <div
                  data-testid="main-time-label"
                  className="whitespace-nowrap"
                >
                  {getFullBucketLabel(main.timeLabel, {
                    isRealtime,
                    interval,
                    shouldShowYear,
                    shouldShowDate,
                    bucketIndex,
                    totalBuckets,
                    isPartial: main.isPartial
                  })}
                </div>
              </div>
              <div
                data-testid="main-value"
                className="font-bold whitespace-nowrap"
              >
                {getFormattedValue(main.value)}
              </div>
            </div>
          )}

          {comparison.isDefined && (
            <div className="flex flex-row justify-between items-center">
              <div className="flex items-center mr-4">
                <div className="size-2 flex-none mr-2 rounded-full bg-gray-500"></div>
                <div className="whitespace-nowrap">
                  {getFullBucketLabel(comparison.timeLabel, {
                    isRealtime,
                    interval,
                    shouldShowYear,
                    shouldShowDate,
                    bucketIndex,
                    totalBuckets,
                    isPartial: comparison.isPartial
                  })}
                </div>
              </div>
              <div
                data-testid="comparison-value"
                className="font-bold whitespace-nowrap"
              >
                {' '}
                {getFormattedValue(comparison.value)}
              </div>
            </div>
          )}
        </div>
        {children}
      </aside>
    </GraphTooltipWrapper>
  )
}

export const MainGraphContainer = React.forwardRef<
  HTMLDivElement,
  { children: ReactNode }
>((props, ref) => {
  return (
    <div
      className="relative mt-4 mb-3 w-full"
      style={{ height: `${height}px` }}
      ref={ref}
    >
      {props.children}
    </div>
  )
})

type BucketLabelParams = {
  shouldShowYear: boolean
  shouldShowDate: boolean
  interval: Interval
  isRealtime: boolean
  bucketIndex: number
  totalBuckets: number
}

const getBucketLabel = (
  // in the format "YYYY-MM-DD" or "YYYY-MM-DD HH:MM:SS"
  xValue: string,
  {
    shouldShowYear,
    shouldShowDate,
    isRealtime,
    interval,
    bucketIndex,
    totalBuckets
  }: BucketLabelParams
) => {
  const parsedDate = parseNaiveDate(xValue)
  switch (interval) {
    case Interval.month:
      return formatMonthYYYY(parsedDate)
    case Interval.week:
    case Interval.day:
      return formatDayShort(parsedDate, shouldShowYear)
    case Interval.hour: {
      const time = formatTime(parsedDate, {
        use12HourClock: is12HourClock(),
        includeMinutes: false
      })
      if (shouldShowDate) {
        return `${formatDayShort(parsedDate, shouldShowYear)}, ${time}`
      }
      return time
    }
    case Interval.minute: {
      if (isRealtime) {
        const minutesAgo = totalBuckets - bucketIndex
        return `-${minutesAgo}m`
      }
      const time = formatTime(parsedDate, {
        use12HourClock: is12HourClock(),
        includeMinutes: true
      })
      if (shouldShowDate) {
        return `${formatDayShort(parsedDate, shouldShowYear)}, ${time}`
      }
      return time
    }
  }
}

const getFullBucketLabel = (
  // in the format "YYYY-MM-DD" or "YYYY-MM-DD HH:MM:SS"
  xValue: string,
  {
    shouldShowYear,
    shouldShowDate,
    isRealtime,
    interval,
    bucketIndex,
    totalBuckets,
    isPartial
  }: BucketLabelParams & { isPartial: boolean }
) => {
  const parsedDate = parseNaiveDate(xValue)
  switch (interval) {
    case Interval.month: {
      const month = getBucketLabel(xValue, {
        shouldShowYear,
        shouldShowDate,
        interval,
        isRealtime,
        bucketIndex,
        totalBuckets
      })
      return isPartial ? `Partial of ${month}` : month
    }
    case Interval.week: {
      const date = getBucketLabel(xValue, {
        shouldShowYear,
        shouldShowDate,
        interval,
        isRealtime,
        bucketIndex,
        totalBuckets
      })
      return isPartial ? `Partial week of ${date}` : `Week of ${date}`
    }
    case Interval.day:
      return formatDay(parsedDate, shouldShowYear)
    case Interval.hour: {
      const time = formatTime(parsedDate, {
        use12HourClock: is12HourClock(),
        includeMinutes: false
      })
      if (shouldShowDate) {
        return `${formatDay(parsedDate, shouldShowYear)}, ${time}`
      }
      return time
    }
    case Interval.minute: {
      if (isRealtime) {
        const minutesAgo = totalBuckets - bucketIndex
        return minutesAgo === 1 ? `1 minute ago` : `${minutesAgo} minutes ago`
      }
      const time = formatTime(parsedDate, {
        use12HourClock: is12HourClock(),
        includeMinutes: true
      })
      if (shouldShowDate) {
        return `${formatDay(parsedDate, shouldShowYear)}, ${time}`
      }
      return time
    }
  }
}

function isYearUnambiguous({
  site,
  startEndLabels
}: {
  site: PlausibleSite
  startEndLabels: (string | null)[]
}): boolean {
  return startEndLabels
    .filter((item) => typeof item === 'string')
    .every(
      (item, _index, items) =>
        parseNaiveDate(items[0]).isSame(parseNaiveDate(item), 'year') &&
        isThisYear(site, parseNaiveDate(items[0]))
    )
}

function isDateUnambiguous({
  startEndLabels
}: {
  startEndLabels: (string | null)[]
}): boolean {
  return startEndLabels
    .filter((item) => typeof item === 'string')
    .every((item, _index, items) =>
      parseNaiveDate(items[0]).isSame(parseNaiveDate(item), 'day')
    )
}

function canZoomToPeriod(
  interval: Interval,
  mainPeriodLengthInDays: number,
  mainPeriodLengthInMonths: number
) {
  return (
    (interval === Interval.day && mainPeriodLengthInDays > 0) ||
    (interval === Interval.month && mainPeriodLengthInMonths > 0)
  )
}

const paletteByTheme = {
  [UIMode.dark]: {
    primaryGradient: {
      id: 'primary-gradient',
      stopTop: { color: '#4f46e5', opacity: 0.15 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    },
    secondaryGradient: {
      id: 'secondary-gradient',
      stopTop: { color: '#4f46e5', opacity: 0.05 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    }
  },
  [UIMode.light]: {
    primaryGradient: {
      id: 'primary-gradient',
      stopTop: { color: '#4f46e5', opacity: 0.15 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    },
    secondaryGradient: {
      id: 'secondary-gradient',
      stopTop: { color: '#4f46e5', opacity: 0.05 },
      stopBottom: { color: '#4f46e5', opacity: 0 }
    }
  }
}

const sharedPathClass = 'fill-none stroke-2'
const mainPathClass = 'stroke-indigo-500 dark:stroke-indigo-400'
const comparisonPathClass =
  'stroke-[rgb(222,221,255)] dark:stroke-[rgb(45,46,76)]'
const roundedPathClass = '[stroke-linecap:round] [stroke-linejoin:round]'
const dashedPathClass = '[stroke-dasharray:3,3]'
const sharedDotClass =
  'opacity-0 group-data-active:opacity-100 transition-opacity duration-100'
const mainDotClass = 'fill-indigo-500 dark:fill-indigo-400'
const comparisonDotClass = 'fill-[rgb(222,221,255)] dark:fill-[rgb(45,46,76)]'

export function useMainGraphWidth(
  mainGraphContainer: React.RefObject<HTMLDivElement>
): { width: number } {
  const [width, setWidth] = useState<number>(0)

  useEffect(() => {
    const resizeObserver = new ResizeObserver(([e]) => {
      setWidth(e.contentRect.width)
    })

    if (mainGraphContainer.current) {
      resizeObserver.observe(mainGraphContainer.current)
    }

    return () => {
      resizeObserver.disconnect()
    }
  }, [mainGraphContainer])

  return {
    width
  }
}
