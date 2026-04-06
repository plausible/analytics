import React, {
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useState
} from 'react'
import { UIMode, useTheme } from '../../theme-context'
import {
  FormattableMetric,
  MetricFormatterShort
} from '../reports/metric-formatter'
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
import { MainGraphResponse } from './fetch-main-graph'
import { remapAndFillData } from './main-graph-data'

const height = 368
const marginTop = 16
const marginRight = 4
const marginBottom = 32
const defaultMarginLeft = 16 // this is adjusted by the Graph component based on y-axis label width
const hoverBuffer = 4

/**
 * A data point for the graph and tooltip:
 * it's x position is its index in GraphDatum[] array,
 * y positions are value, comparisonValue.
 * Remapped from @see MainGraphResponse to fill empty buckets that BE
 * doesn't return.
 */
type GraphDatum = {
  value: number | null
  isPartial: boolean | null
  timeLabel: string | null
  comparisonValue?: number | null
  comparisonTimeLabel?: string | null
  change?: number | null
}

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
      yMax,
      startOfLastPartialSlice,
      mainSeriesStartEndLabels,
      comparisonSeriesStartEndLabels
    } = remapAndFillData({
      data,
      metric
    })

    const gradients = [primaryGradient, secondaryGradient]

    const mainSeries: SeriesConfig = {
      lines:
        startOfLastPartialSlice !== null && startOfLastPartialSlice > 0
          ? [
              {
                lineClassName: classNames(
                  sharedPathClass,
                  mainPathClass,
                  roundedPathClass
                ),
                stopIndexExclusive: startOfLastPartialSlice
              },
              {
                lineClassName: classNames(
                  sharedPathClass,
                  mainPathClass,
                  dashedPathClass
                ),
                startIndexInclusive: startOfLastPartialSlice - 1
              }
            ]
          : [
              {
                lineClassName: classNames(
                  sharedPathClass,
                  mainPathClass,
                  roundedPathClass
                )
              }
            ],
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

    // can't be done in a single pass with remapAndFillData
    // because we need the xLabels formatting parameters to be known
    const remappedDataInGraphFormat = remappedData.map((d, bucketIndex) => ({
      values: [d.value ?? null, d.comparisonValue ?? null] as const,
      xLabel:
        d.timeLabel !== null
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
    }))
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

  const yFormat = useCallback(
    (v: { valueOf(): number }) => MetricFormatterShort[metric](v),
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

  return (
    <Graph<Readonly<[number | null, number | null]>>
      className={
        showZoomToPeriod &&
        selectedIndex !== null &&
        remappedData[selectedIndex]
          ? 'cursor-pointer'
          : ''
      }
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
        selectedIndex !== null && showZoomToPeriod
          ? () =>
              navigate({
                search: (currentSearch) => ({
                  ...currentSearch,
                  date:
                    remappedData[selectedIndex].timeLabel ??
                    remappedData[selectedIndex].comparisonTimeLabel,
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
      {selectedIndex !== null && remappedData[selectedIndex] && (
        <MainGraphTooltip
          maxX={width}
          showZoomToPeriod={showZoomToPeriod}
          shouldShowYear={!yearIsUnambiguous}
          shouldShowDate={!dateIsUnambiguous}
          period={period}
          interval={interval}
          metric={metric}
          x={tooltip.x}
          y={tooltip.y}
          datum={remappedData[selectedIndex]}
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
  metric: FormattableMetric
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
  const formatter = MetricFormatterShort[metric]

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
            {METRIC_LABELS[metric as keyof typeof METRIC_LABELS]}
          </div>
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
                    isPartial: datum.isPartial!
                  })}
                </div>
              </div>
              <div className="font-bold whitespace-nowrap">
                {formatter(datum.value)}
              </div>
            </div>
          )}

          {typeof datum.comparisonTimeLabel === 'string' && (
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
                {formatter(datum.comparisonValue)}
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
