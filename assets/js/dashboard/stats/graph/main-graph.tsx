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
import { MainGraphResponse, RevenueMetricValue } from './fetch-main-graph'
import {
  remapAndFillData,
  getLineSegments,
  GraphDatum,
  METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS,
  getChangeInPercentagePoints,
  getRelativeChange,
  REVENUE_METRICS
} from './main-graph-data'
import { getMetricLabel } from '../metrics'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { hasConversionGoalFilter } from '../../util/filters'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const defaultMarginLeft = 16 // this is adjusted by the Graph component based on y-axis label width
const hoverBuffer = 4

type MainGraphData = MainGraphResponse & {
  period: DashboardPeriod
  interval: string
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
  const [isTouchDevice, setIsTouchDevice] = useState(false)
  const [tooltip, setTooltip] = useState<{
    x: number
    y: number
    selectedIndex: number | null
  }>({ x: 0, y: 0, selectedIndex: null })
  const { selectedIndex } = tooltip
  const metric = data.query.metrics[0] as Metric
  const interval = data.interval
  const period = data.period
  const {
    remappedData,
    yMax,
    dateIsUnambiguous,
    yearIsUnambiguous,
    settings,
    remappedDataInGraphFormat,
    gradients
  } = useMemo(() => {
    const {
      remappedData,
      mainSeriesStartEndLabels,
      comparisonSeriesStartEndLabels
    } = remapAndFillData({
      getValue: (item) => item.metrics[0],
      getNumericValue: REVENUE_METRICS.includes(metric)
        ? (v) => (v as RevenueMetricValue).value
        : (v) => v as number,
      getChange: METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS.includes(metric)
        ? getChangeInPercentagePoints
        : getRelativeChange,
      data
    })

    const gradients = [primaryGradient, secondaryGradient]

    const lineSegments = getLineSegments(remappedData)

    let yMax = 1

    // can't be done in a single pass with remapAndFillData
    // because we need the xLabels formatting parameters to be known
    const remappedDataInGraphFormat = remappedData.map((d, bucketIndex) => {
      const dataPoint = {
        values: [
          d.mainSeriesDefined ? d.numericValue : null,
          d.comparisonSeriesDefined ? d.comparisonNumericValue : null
        ] as const,
        xLabel: d.mainSeriesDefined
          ? getBucketLabel(d.timeLabel, {
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
      if (d.mainSeriesDefined && d.numericValue > yMax) {
        yMax = d.numericValue
      }
      if (d.comparisonSeriesDefined && d.comparisonNumericValue > yMax) {
        yMax = d.comparisonNumericValue
      }
      return dataPoint
    })

    const mainSeries: SeriesConfig = {
      lines: lineSegments.map(
        ({ startIndexInclusive, stopIndexExclusive, type }) => ({
          startIndexInclusive,
          stopIndexExclusive,
          lineClassName: classNames(
            sharedPathClass,
            mainPathClass,
            { partial: dashedPathClass, full: roundedPathClass }[type]
          )
        })
      ),
      underline: { gradientId: primaryGradient.id },
      dot: { dotClassName: classNames(sharedDotClass, mainDotClass) }
    }

    const comparisonSeries: SeriesConfig = {
      lines: [
        {
          lineClassName: classNames(sharedPathClass, comparisonPathClass)
        }
      ],
      underline: { gradientId: secondaryGradient.id },
      dot: { dotClassName: classNames(sharedDotClass, comparisonDotClass) }
    }

    const settings: [SeriesConfig, SeriesConfig] = [
      mainSeries,
      comparisonSeries
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

    return {
      remappedData,
      remappedDataInGraphFormat,
      yMax,
      dateIsUnambiguous,
      yearIsUnambiguous,
      settings,
      gradients
    }
  }, [site, data, interval, period, primaryGradient, secondaryGradient, metric])

  const getFormattedValue = useCallback(
    (value: number | RevenueMetricValue) => MetricFormatterShort[metric](value),
    [metric]
  )
  const yFormat = useCallback(
    (numericValue: d3.NumberValue) =>
      MetricFormatterShort[metric](numericValue),
    [metric]
  )

  const onPointerMove = useCallback<PointerHandler>(
    ({ inHoverableArea, closestIndex, x, y, event }) => {
      if (event instanceof PointerEvent) {
        setIsTouchDevice(event.pointerType === 'touch')
      }
      if (!inHoverableArea) {
        setTooltip({ selectedIndex: null, x: 0, y: 0 })
      } else {
        setTooltip({
          selectedIndex: closestIndex,
          x: Math.floor(x),
          y: Math.floor(y)
        })
      }
    },
    []
  )

  const onPointerLeave = useCallback(() => {
    setTooltip({ selectedIndex: null, x: 0, y: 0 })
  }, [])

  const showZoomToPeriod = ['month', 'day'].includes(interval)
  const selectedDatum = selectedIndex !== null && remappedData[selectedIndex]

  const zoomDate =
    selectedDatum && selectedDatum.mainSeriesDefined
      ? selectedDatum.timeLabel
      : null

  return (
    <Graph<Readonly<[number | null, number | null]>>
      className={showZoomToPeriod && selectedDatum ? 'cursor-pointer' : ''}
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
      onPointerMove={onPointerMove}
      onPointerLeave={onPointerLeave}
      onClick={
        selectedIndex !== null &&
        showZoomToPeriod &&
        typeof zoomDate === 'string'
          ? () =>
              navigate({
                search: (currentSearch) => ({
                  ...currentSearch,
                  date: zoomDate,
                  period: {
                    month: DashboardPeriod.month,
                    day: DashboardPeriod.day
                  }[interval]
                })
              })
          : undefined
      }
      yFormat={yFormat}
      gradients={gradients}
    >
      {selectedDatum && (
        <MainGraphTooltip
          getFormattedValue={getFormattedValue}
          maxX={width}
          showZoomToPeriod={showZoomToPeriod}
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
          isTouchDevice={isTouchDevice}
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
  isTouchDevice
}: {
  metric: Metric
  getFormattedValue: (value: RevenueMetricValue | number) => string
  interval: string
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
  isTouchDevice: boolean
}) => {
  const { dashboardState } = useDashboardStateContext()
  const metricLabel = getMetricLabel(metric, {
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })

  return (
    <GraphTooltipWrapper
      x={x}
      y={y}
      minWidth={200}
      maxX={maxX}
      isTouchDevice={isTouchDevice}
      className={
        'absolute z-10 select-none pointer-events-none bg-gray-800 dark:bg-gray-950 py-3 px-4 rounded-md shadow shadow-gray-200 dark:shadow-gray-850'
      }
    >
      <aside className="text-sm font-normal text-gray-100 flex flex-col gap-1.5">
        <div className="flex justify-between items-center rounded-sm">
          <div className="font-semibold mr-4 text-xs uppercase whitespace-nowrap">
            {metricLabel}
          </div>
          {datum.comparisonSeriesDefined &&
            typeof datum.change === 'number' && (
              <ChangeArrow
                className="text-xs/6 font-medium text-white whitespace-nowrap"
                metric={metric}
                change={datum.change}
              />
            )}
        </div>
        <div className="flex flex-col">
          {datum.mainSeriesDefined && (
            <div className="flex flex-row justify-between items-center">
              <div className="flex items-center mr-4">
                <div className="size-2 flex-none mr-2 rounded-full bg-indigo-400" />
                <div className="whitespace-nowrap">
                  {getFullBucketLabel(datum.timeLabel, {
                    period,
                    interval,
                    shouldShowYear,
                    shouldShowDate,
                    bucketIndex,
                    totalBuckets,
                    isPartial: datum.isPartial
                  })}
                </div>
              </div>
              <div className="font-bold whitespace-nowrap">
                {getFormattedValue(datum.value)}
              </div>
            </div>
          )}

          {datum.comparisonSeriesDefined && (
            <div className="flex flex-row justify-between items-center">
              <div className="flex items-center mr-4">
                <div className="size-2 flex-none mr-2 rounded-full bg-gray-500"></div>
                <div className="whitespace-nowrap">
                  {getFullBucketLabel(datum.comparisonTimeLabel, {
                    period,
                    interval,
                    shouldShowYear,
                    shouldShowDate,
                    bucketIndex,
                    totalBuckets,
                    isPartial: false
                  })}
                </div>
              </div>
              <div className="font-bold whitespace-nowrap">
                {' '}
                {getFormattedValue(datum.comparisonValue)}
              </div>
            </div>
          )}
        </div>

        {!!showZoomToPeriod && (
          <>
            <hr className="border-gray-600 dark:border-gray-800 my-1" />
            <span className="text-gray-300 dark:text-gray-400 text-xs">
              {isTouchDevice
                ? `Release to view ${interval}`
                : `Click to view ${interval}`}
            </span>
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
  /* "month" | "week" | "day" | "hour" | "minute" */
  interval: string
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
    case 'month':
      return formatMonthYYYY(parsedDate)
    case 'week':
    case 'day':
      return formatDayShort(parsedDate, shouldShowYear)
    case 'hour': {
      const time = formatTime(parsedDate, {
        use12HourClock: is12HourClock(),
        includeMinutes: false
      })
      if (shouldShowDate) {
        return `${formatDayShort(parsedDate, shouldShowYear)}, ${time}`
      }
      return time
    }
    case 'minute': {
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
    default:
      return ''
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
    case 'month': {
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
    case 'week': {
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
    case 'day':
      return formatDay(parsedDate, shouldShowYear)
    case 'hour': {
      const time = formatTime(parsedDate, {
        use12HourClock: is12HourClock(),
        includeMinutes: false
      })
      if (shouldShowDate) {
        return `${formatDay(parsedDate, shouldShowYear)}, ${time}`
      }
      return time
    }
    case 'minute': {
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
    default:
      return ''
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
const mainPathClass = 'stroke-indigo-500 dark:stroke-indigo-400 z-2'
const comparisonPathClass = 'stroke-indigo-500/20 dark:stroke-indigo-400/20 z-1'
const roundedPathClass = '[stroke-linecap:round] [stroke-linejoin:round]'
const dashedPathClass = '[stroke-dasharray:3,3]'
const sharedDotClass =
  'opacity-0 group-data-active:opacity-100 transition-opacity duration-100'
const mainDotClass = 'fill-indigo-500 dark:fill-indigo-400'
const comparisonDotClass = 'fill-indigo-500/20 dark:fill-indigo-400/20'

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
