import React, {
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
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
import { Metric } from '../../../types/query-api'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { Graph, PointerHandler, SeriesConfig } from '../../components/graph'
import { useSiteContext, PlausibleSite } from '../../site-context'
import { GraphTooltipWrapper } from '../../components/graph-tooltip'
import {
  MainGraphResponse,
  MetricValue,
  RevenueMetricValue
} from './fetch-main-graph'
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
import { getMetricLabel } from '../metrics'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { hasConversionGoalFilter } from '../../util/filters'
import { Interval } from './intervals'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const defaultMarginLeft = 16 // this is adjusted by the Graph component based on y-axis label width
const hoverBuffer = 4

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
  persistent: false
}

export const MainGraph = ({
  width,
  data
}: {
  width: number
  data: MainGraphData
}) => {
  const site = useSiteContext()
  const { mode } = useTheme()
  const navigate = useAppNavigate()
  const { primaryGradient, secondaryGradient } = paletteByTheme[mode]
  const [isTouchDevice, setIsTouchDevice] = useState<null | boolean>(null)
  const [tooltip, setTooltip] = useState<TooltipState>(initialTooltipState)
  const { selectedIndex } = tooltip
  const metric = data.query.metrics[0] as Metric
  const interval = data.interval
  const period = data.period

  useEffect(() => {
    setTooltip(initialTooltipState)
  }, [data])

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
    ({ inHoverableArea, closestPoint, xPointer, yPointer, event }) => {
      if (event instanceof PointerEvent && event.pointerType === 'touch') {
        return setIsTouchDevice(true)
      }
      setIsTouchDevice(false)
      if (!inHoverableArea || !closestPoint) {
        return setTooltip(initialTooltipState)
      }
      return setTooltip({
        selectedIndex: closestPoint.index,
        x: Math.floor(xPointer),
        y: Math.floor(yPointer),
        persistent: false
      })
    },
    []
  )

  const onGotPointerCapture = useCallback((event: unknown) => {
    if (event instanceof PointerEvent && event.pointerType === 'touch') {
      return setIsTouchDevice(true)
    }
  }, [])

  const onPointerEnter = useCallback((event: unknown) => {
    if (event instanceof PointerEvent && event.pointerType === 'touch') {
      return setIsTouchDevice(true)
    }
  }, [])

  const onPointerLeave = useCallback(() => {
    setTooltip(initialTooltipState)
  }, [])

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

  const onClick = useCallback<PointerHandler<MainGraphYValues>>(
    ({ inHoverableArea, closestPoint }) => {
      if (isTouchDevice) {
        if (inHoverableArea && closestPoint) {
          return setTooltip({
            selectedIndex: closestPoint.index,
            x: closestPoint.x,
            y: Math.min(...closestPoint.values.filter((y) => y !== null)),
            persistent: true
          })
        }
        return setTooltip(initialTooltipState)
      }
      if (typeof zoomDate === 'string') {
        return zoomToPeriod(zoomDate)
      }
    },
    [zoomDate, zoomToPeriod, isTouchDevice]
  )

  return (
    <Graph<MainGraphYValues>
      className={showZoomToPeriod && selectedDatum ? 'cursor-pointer' : ''}
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
      onClick={onClick}
      yFormat={yFormat}
      gradients={gradients}
    >
      {!!selectedDatum && isTouchDevice !== null && (
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
          onClick={
            tooltip.persistent && typeof zoomDate === 'string'
              ? () => zoomToPeriod(zoomDate)
              : undefined
          }
        />
      )}
    </Graph>
  )
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
  showZoomToPeriod,
  bucketIndex,
  totalBuckets,
  persistent,
  onClick
}: {
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
  onClick?: () => void
}) => {
  const { dashboardState } = useDashboardStateContext()
  const metricLabel = getMetricLabel(metric, {
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })
  const { main, comparison, change } = datum
  return (
    <GraphTooltipWrapper
      x={x}
      y={y}
      minWidth={200}
      maxX={maxX}
      className={classNames(
        'absolute select-none bg-gray-800 dark:bg-gray-950 py-3 px-4 rounded-md shadow shadow-gray-200 dark:shadow-gray-850',
        typeof onClick !== 'function' && 'pointer-events-none'
      )}
      transition={
        persistent
          ? {
              // enter delay on mobile is needed to prevent the tooltip from entering when the user starts to y-pan
              // but the y-pan is not yet certain
              enter: 'transition-opacity duration-0 delay-150',
              enterFrom: 'opacity-0',
              enterTo: 'opacity-100'
            }
          : {}
      }
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

        {!!showZoomToPeriod && (
          <>
            <hr className="border-gray-600 dark:border-gray-800 my-1" />
            {!persistent && (
              <span className="text-gray-300 dark:text-gray-400 text-xs">
                {`Click to view ${interval}`}
              </span>
            )}
            {persistent && (
              <button
                className="button"
                onClick={onClick}
              >{`View ${interval}`}</button>
            )}
          </>
        )}
      </aside>
    </GraphTooltipWrapper>
  )
}

export const MainGraphContainer = React.forwardRef<
  HTMLDivElement,
  { children: ReactNode }
>((props, ref) => {
  return (
    <div className="relative my-4 h-92 w-full" ref={ref}>
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
