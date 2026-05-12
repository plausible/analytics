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
import { useDashboardStateContext } from '../../dashboard-state-context'
import { hasConversionGoalFilter } from '../../util/filters'
import { Interval } from './intervals'
import { useRoutelessModalsContext } from '../../navigation/routeless-modals-context'
import {
  Annotation,
  AnnotationType,
  getAnnotationGranularity,
  groupAnnotationsByTimeLabel
} from '../../annotations/annotations'
import { Button } from '../../components/button'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const defaultMarginLeft = 16 // this is adjusted by the Graph component based on y-axis label width
const hoverBuffer = 4
const HORIZONTAL_PAN_DELAY_MS = 100

type MainGraphData = MainGraphResponse & {
  period: DashboardPeriod
  interval: Interval
}

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
  y: number
  selectedIndex: number | null
  persistent: boolean
}

const initialTooltipState: TooltipState = {
  x: 0,
  y: 0,
  selectedIndex: null,
  persistent: false,
}

export const MainGraph = ({
  width,
  data,
  annotations
}: {
  width: number
  data: MainGraphData
  annotations: Annotation[]
}) => {
  const site = useSiteContext()
  const { mode } = useTheme()
  const navigate = useAppNavigate()

  const { primaryGradient, secondaryGradient } = paletteByTheme[mode]

  const [isTouchDevice, setIsTouchDevice] = useState<null | boolean>(null)
  const [pinnedAnnotationIds, setPinnedAnnotationIds] = useState<
    Record<number, { x: number; selectedIndex: number } | null>
  >({})
  const [tooltip, setTooltip] = useState<TooltipState>(initialTooltipState)
  const tooltipRef = useRef<HTMLDivElement>(null)

  const { selectedIndex } = tooltip
  const panGestureStartTimeRef = useRef<number | null>(null)

  const metric = data.query.metrics[0] as Metric
  const interval = data.interval
  const period = data.period

  const annotationsByTimeLabel = useMemo(
    () => groupAnnotationsByTimeLabel(annotations, interval),
    [annotations, interval]
  )

  useEffect(() => {
    setTooltip(initialTooltipState)
  }, [data, annotationsByTimeLabel])

  useEffect(() => {
    const onClickOutside = (event: MouseEvent) => {
      if (!tooltipRef.current?.contains(event.target as Node)) {
        setTooltip(initialTooltipState)
      }
    }
    if (tooltip.persistent && isTouchDevice === false) {
      document.addEventListener('click', onClickOutside)
    } else {
      document.removeEventListener('click', onClickOutside)
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
                period,
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
  }, [site, data, interval, period, primaryGradient, secondaryGradient, metric])

  const annotationsCountByIndex = useMemo(
    () =>
      remappedData.map((datum) => {
        const annotationsOnDatum = datum.main.isDefined
          ? (annotationsByTimeLabel[datum.main.timeLabel] ?? [])
          : []
        return annotationsOnDatum.length
      }),
    [remappedData, annotationsByTimeLabel]
  )

  const verticalLineIndices = useMemo(
    () =>
      remappedData.reduce<number[]>((acc, datum, index) => {
        if (!datum.main.isDefined) return acc
        const annotationsOnDatum =
          annotationsByTimeLabel[datum.main.timeLabel] ?? []
        const hasPinned = annotationsOnDatum.some(
          (a) => pinnedAnnotationIds[a.id] != null
        )
        if (hasPinned) acc.push(index)
        return acc
      }, []),
    [remappedData, annotationsByTimeLabel, pinnedAnnotationIds]
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
              y: 0,
              persistent: true,
            })
          }
        }
        return
      }
      setIsTouchDevice(false)
      setTooltip((currentState) => {
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
          x: closestPoint.x,
          y: 0,
          type: 'series'
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
    ({ inHoverableArea, closestPoint }) => {
      if (isTouchDevice) {
        if (inHoverableArea && closestPoint) {
          return setTooltip({
            selectedIndex: closestPoint.index,
            x: closestPoint.x,
            y: 0,
            persistent: true,
          })
        }
        return setTooltip(initialTooltipState)
      }

      if (tooltip.persistent) {
        return
      }
      // const isAltClick = event instanceof PointerEvent && event.altKey
      // if (annotationDatetime && isAltClick) {
      //   return openAnnotationModal(annotationDatetime)
      // }
      if (typeof zoomDate === 'string') {
        return zoomToPeriod(zoomDate)
      }
    },
    [
      isTouchDevice,
      zoomDate,
      // annotationDatetime,
      zoomToPeriod,
      // openAnnotationModal,
      tooltip.persistent
    ]
  )

  const onContextMenu = useCallback<PointerHandler<MainGraphYValues>>(
    ({ inHoverableArea, closestPoint }) => {
      if (inHoverableArea && closestPoint) {
        return setTooltip({
          selectedIndex: closestPoint.index,
          x: closestPoint.x,
          y: 0,
          persistent: true,
        })
      }
      return setTooltip(initialTooltipState)
    },
    []
  )

  return (
    <Graph<MainGraphYValues>
      className={classNames({
        'cursor-pointer':
          selectedDatum && showZoomToPeriod,
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
      annotationsCountByIndex={annotationsCountByIndex}
      verticalLineIndices={verticalLineIndices}
    >
      {Object.entries(annotationsByTimeLabel)
        .map(([_timeLabel, annotations]) => {
          const pinnedAnnotations = annotations?.filter(
            (a) => pinnedAnnotationIds[a.id] != null
          )
          const pinState =
            pinnedAnnotations && pinnedAnnotations.length
              ? pinnedAnnotationIds[pinnedAnnotations[0].id]
              : null
          return [pinState, pinnedAnnotations] as const
        })
        .filter(
          ([pinState]) =>
            pinState !== null && pinState!.selectedIndex !== selectedIndex
        )
        .sort(([a], [b]) => a!.x - b!.x)
        .map(([pinState, pinnedAnnotations]) => (
          <PinnedAnnotationsTooltip
            key={pinState!.x}
            x={pinState!.x}
            maxX={width}
            annotations={pinnedAnnotations!}
            onClick={() =>
              setTooltip({
                selectedIndex: pinState!.selectedIndex,
                x: pinState!.x,
                y: 0,
                persistent: true,
              })
            }
          />
        ))}
      {!!selectedDatum &&
        isTouchDevice !== null &&
         (
          <MainGraphTooltip
            getFormattedValue={getFormattedValue}
            maxX={width}
            showZoomToPeriod={!!zoomDate}
            shouldShowYear={!yearIsUnambiguous}
            shouldShowDate={!dateIsUnambiguous}
            period={period}
            interval={interval}
            metric={metric}
            x={tooltip.x}
            y={tooltip.y}
            datum={selectedDatum}
            bucketIndex={selectedIndex}
            totalBuckets={remappedData.length}
            persistent={tooltip.persistent}
            tooltipRef={tooltipRef}
            isTouchDevice={isTouchDevice}
          >
            {tooltip.persistent && (
              <>
                {!!annotationDatetime &&
                  !!annotationsByTimeLabel[annotationDatetime] && (
                    <InteractiveAnnotationsList
                      pinnedAnnotationIds={pinnedAnnotationIds}
                      onPin={(annotation) =>
                        setPinnedAnnotationIds((current) => ({
                          ...current,
                          [annotation.id]:
                            current[annotation.id] != null
                              ? null
                              : {
                                  x: tooltip.x,
                                  selectedIndex: tooltip.selectedIndex ?? 0
                                }
                        }))
                      }
                      annotations={annotationsByTimeLabel[annotationDatetime]}
                    />
                  )}
                {!!annotationDatetime && (
                  <AddAnnotationButton
                    interval={interval}
                    timelabel={annotationDatetime}
                  />
                )}
                {!!zoomDate && (
                  <Button
                    onClick={() => zoomToPeriod(zoomDate)}
                  >{`View ${interval}`}</Button>
                )}
              </>
            )}
            {!tooltip.persistent && (
              <>
                {!!annotationDatetime &&
                  !!annotationsByTimeLabel[annotationDatetime] && (
                    <>
                      <AnnotationsList
                        pinnedAnnotationIds={[]}
                        expandedIndex={null}
                        annotations={annotationsByTimeLabel[
                          annotationDatetime
                        ].slice(0, 1)}
                        onAnnotationClick={() => {}}
                      />
                      {annotationsByTimeLabel[annotationDatetime].length == 2 &&
                        `and 1 more note`}
                      {annotationsByTimeLabel[annotationDatetime].length > 2 &&
                        `and ${annotationsByTimeLabel[annotationDatetime].length - 1} more notes`}
                    </>
                  )}
                {(!!zoomDate || !!annotationDatetime) && (
                  <hr className="border-gray-600 dark:border-gray-800 my-1" />
                )}
                {!!zoomDate && (
                  <div className="text-gray-300 dark:text-gray-400 text-xs">
                    {`Click to view ${interval}`}
                  </div>
                )}
                {!!annotationDatetime && (
                  <div className="text-gray-300 dark:text-gray-400 text-xs">
                    Right click for more actions
                  </div>
                )}
              </>
            )}
          </MainGraphTooltip>
        )}
    </Graph>
  )
}

const InteractiveAnnotationsList = ({
  annotations,
  pinnedAnnotationIds,
  onPin
}: {
  pinnedAnnotationIds: Record<
    number,
    { x: number; selectedIndex: number } | null
  >
  onPin: (annotation: Annotation) => void
  annotations: Annotation[]
}) => {
  const [expanded, setExpanded] = useState<number | null>(null)
  useEffect(() => {
    setExpanded(null)
  }, [annotations])
  const { setModal } = useRoutelessModalsContext()

  return (
    <AnnotationsList
      pinnedAnnotationIds={pinnedAnnotationIds}
      annotations={annotations}
      expandedIndex={expanded}
      onAnnotationClick={(index: number) =>
        setExpanded((current) => (current === index ? null : index))
      }
      onEdit={(annotation) =>
        setModal({ type: 'update-annotation', annotation })
      }
      onDelete={(annotation) =>
        setModal({ type: 'delete-annotation', annotation })
      }
      onPin={onPin}
    />
  )
}

const AnnotationsList = ({
  pinnedAnnotationIds,
  annotations,
  expandedIndex,
  onAnnotationClick,
  onEdit,
  onPin,
  onDelete
}: {
  pinnedAnnotationIds: Record<
    number,
    { x: number; selectedIndex: number } | null
  >
  annotations: Annotation[]
  onEdit?: (annotation: Annotation) => void
  onPin?: (annotation: Annotation) => void
  onDelete?: (annotation: Annotation) => void
  expandedIndex: number | null
  onAnnotationClick?: (index: number) => void
}) => {
  return (
    <div className="text-sm font-normal text-gray-100 flex flex-col gap-1.5">
      {annotations.map((annotation, index) => {
        const { id, note } = annotation
        return (
          <div className="flex flex-row gap-x-2" key={id}>
            <div className="rounded-xs w-[3px] bg-green-500 shrink-0" />
            <div className="flex flex-col gap-y-1 w-64">
              {typeof onAnnotationClick === 'function' ? (
                <button
                  className="flex flex-row"
                  onClick={() => onAnnotationClick(index)}
                >
                  <div className="text-left break-all">{note}</div>
                </button>
              ) : (
                <div className="text-left break-all">{note}</div>
              )}
              {expandedIndex === index && (
                <div className="flex flex-row">
                  {typeof onEdit === 'function' && (
                    <Button
                      theme="ghost"
                      size="sm"
                      onClick={() => onEdit(annotation)}
                    >
                      {/* <PencilIcon className="w-4 h-4 block" /> */}
                      Edit
                    </Button>
                  )}
                  {typeof onPin === 'function' &&
                    (pinnedAnnotationIds[annotation.id] ? (
                      <Button
                        theme="ghost"
                        size="sm"
                        onClick={() => onPin(annotation)}
                      >
                        {/* <BookmarkSlashIcon className="w-4 h-4 block" /> */}
                        Unpin
                      </Button>
                    ) : (
                      <Button
                        theme="ghost"
                        size="sm"
                        onClick={() => onPin(annotation)}
                      >
                        {/* <BookmarkIcon className="w-4 h-4 block" /> */}
                        Pin
                      </Button>
                    ))}
                  {typeof onDelete === 'function' && (
                    <Button
                      theme="ghost"
                      size="sm"
                      onClick={() => onDelete(annotation)}
                    >
                      {/* <TrashIcon className="w-4 h-4 block" /> */}
                      Delete
                    </Button>
                  )}
                </div>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}

const AddAnnotationButton = ({
  interval,
  timelabel
}: {
  interval: Interval
  timelabel: string
}) => {
  const { setModal } = useRoutelessModalsContext()

  return (
    <Button
      size="sm"
      onClick={() =>
        setModal({
          type: 'create-annotation',
          annotation: {
            note: `Note on ${timelabel}`,
            type: AnnotationType.personal,
            datetime: timelabel,
            granularity: getAnnotationGranularity(interval)
          }
        })
      }
    >
      Add note
    </Button>
  )
}

const isTouchEvent = (event: unknown) =>
  event instanceof PointerEvent && event.pointerType === 'touch'

const mainGraphTooltipClassName =
  'absolute bg-gray-800 dark:bg-gray-950 py-3 px-4 rounded-md shadow shadow-gray-200 dark:shadow-gray-850 w-max max-w-[300px]'

type MainGraphTooltipProps = {
  metric: Metric
  getFormattedValue: (value: MetricValue) => string
  interval: Interval
  period: DashboardPeriod
  shouldShowYear: boolean
  shouldShowDate: boolean
  x: number
  y: number
  datum: GraphDatum
  showZoomToPeriod?: boolean
  bucketIndex: number
  totalBuckets: number
  maxX: number
  persistent: boolean
  children?: ReactNode
  tooltipRef: RefObject<HTMLDivElement>
  isTouchDevice: boolean
}

const MainGraphTooltip = ({
  metric,
  getFormattedValue,
  interval,
  period,
  shouldShowDate,
  shouldShowYear,
  maxX,
  x,
  y,
  datum,
  bucketIndex,
  totalBuckets,
  persistent,
  children,
  tooltipRef,
  isTouchDevice
}: MainGraphTooltipProps) => {
  const { dashboardState } = useDashboardStateContext()
  const metricLabel = getMetricLabel(metric, {
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })
  const { main, comparison, change } = datum
  return (
    <GraphTooltipWrapper
      wrapperRef={tooltipRef}
      horizontalAnchor="start"
      verticalAnchor="topEdge"
      x={x}
      y={y}
      minWidth={200}
      maxX={maxX}
      className={classNames(mainGraphTooltipClassName, {
        'select-none': !persistent || isTouchDevice,
        'pointer-events-none': !persistent
      })}
    >
      <aside className="text-sm font-normal text-gray-100 flex flex-col gap-1.5">
        <div className="flex justify-between items-center rounded-sm">
          <div className="font-semibold mr-4 text-xs uppercase whitespace-nowrap">
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
                <div className="whitespace-nowrap">
                  {getFullBucketLabel(main.timeLabel, {
                    period,
                    interval,
                    shouldShowYear,
                    shouldShowDate,
                    bucketIndex,
                    totalBuckets,
                    isPartial: main.isPartial
                  })}
                </div>
              </div>
              <div className="font-bold whitespace-nowrap">
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
                    period,
                    interval,
                    shouldShowYear,
                    shouldShowDate,
                    bucketIndex,
                    totalBuckets,
                    isPartial: comparison.isPartial
                  })}
                </div>
              </div>
              <div className="font-bold whitespace-nowrap">
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

const PinnedAnnotationsTooltip = ({
  x,
  annotations,
  maxX,
  onClick
}: {
  x: number
  maxX: number
  annotations: Annotation[]
  onClick: () => void
}) => {
  const ref = useRef<HTMLDivElement>(null)
  return (
    <GraphTooltipWrapper
      horizontalAnchor="start"
      verticalAnchor="topEdge"
      x={x!}
      y={0}
      maxX={maxX}
      minWidth={200}
      wrapperRef={ref}
      key={x}
      className={mainGraphTooltipClassName}
    >
      <div
        className="cursor-pointer"
        onClick={(e) => {
          e.stopPropagation()
          onClick()
        }}
      >
        <AnnotationsList
          annotations={annotations}
          expandedIndex={null}
          pinnedAnnotationIds={{}}
        />
      </div>
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
  period: DashboardPeriod
  bucketIndex: number
  totalBuckets: number
}

const getBucketLabel = (
  // in the format "YYYY-MM-DD" or "YYYY-MM-DD HH:MM:SS"
  xValue: string,
  {
    shouldShowYear,
    shouldShowDate,
    period,
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
      if (period === DashboardPeriod.realtime) {
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
    period,
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
        period,
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
        period,
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
      if (period === DashboardPeriod.realtime) {
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
