import {
  MainGraphResponse,
  ResultItem,
  RevenueMetricValue
} from './fetch-main-graph'

/**
 * Fills gaps in @see MainGraphResponse the series of `results` and `comparisonResults`.
 * The BE doesn't return buckets in the series where the value is 0:
 * these need to filled by the FE to have a consistent plot.
 *
 * The assumption is that the two series each are continuously defined.
 *
 * Extracts the numeric values for the series when they are wrapped.
 *
 * In the same single loop, for the sake of efficiency, it determines
 * - the maximum y value (used for scaling the graph),
 * - the start and end labels of both series (used for generating appropriate X axis labels),
 *
 */
export const remapAndFillData = ({
  data,
  getNumericValue,
  getValue,
  getChange
}: {
  data: MainGraphResponse
  getNumericValue: (metrics: RevenueMetricValue | number) => number
  getValue: (item: Pick<ResultItem, 'metrics'>) => RevenueMetricValue | number
  getChange: (value: number, comparisonValue: number) => number
}): {
  remappedData: GraphDatum[]
  mainSeriesStartEndLabels: [string | null, string | null]
  comparisonSeriesStartEndLabels: [string | null, string | null]
} => {
  const totalBucketCount = Math.max(
    data.meta.comparison_time_label_result_indices?.length ?? 0,
    data.meta.time_label_result_indices.length
  )

  let firstTimeLabel: null | string = null
  let lastTimeLabel: null | string = null

  let firstComparisonTimeLabel: null | string = null
  let lastComparisonTimeLabel: null | string = null

  const remappedData: GraphDatum[] = new Array(totalBucketCount)
    .fill(null)
    .map((_, index) => {
      const timeLabel = data.meta.time_labels[index] ?? null
      const indexOfResult = data.meta.time_label_result_indices[index] ?? null
      const comparisonTimeLabel =
        (data.meta.comparison_time_labels &&
          data.meta.comparison_time_labels[index]) ??
        null
      const indexOfComparisonResult =
        (data.meta.comparison_time_label_result_indices &&
          data.meta.comparison_time_label_result_indices[index]) ??
        null

      const mainSeriesDefined = typeof timeLabel === 'string'
      const comparisonSeriesDefined = typeof comparisonTimeLabel === 'string'

      let mainSeries: MainSeriesValue
      let comparisonSeries: ComparisonSeriesValue
      let change = null

      if (mainSeriesDefined) {
        const isPartial = (data.meta.partial_time_labels ?? []).find(
          (l) => l === timeLabel
        )
          ? true
          : false

        if (firstTimeLabel === null) {
          firstTimeLabel = timeLabel
        }

        lastTimeLabel = timeLabel

        const outerValue =
          indexOfResult !== null
            ? getValue(data.results[indexOfResult]!)
            : getValue({ metrics: data.meta.empty_metrics })
        const value = getNumericValue(outerValue)

        mainSeries = {
          mainSeriesDefined,
          value,
          outerValue,
          isPartial,
          timeLabel
        }
      } else {
        mainSeries = { mainSeriesDefined }
      }

      if (comparisonSeriesDefined) {
        if (firstComparisonTimeLabel === null) {
          firstComparisonTimeLabel = comparisonTimeLabel
        }

        lastComparisonTimeLabel = comparisonTimeLabel

        const comparisonOuterValue =
          indexOfComparisonResult !== null
            ? getValue(data.comparison_results[indexOfComparisonResult]!)
            : getValue({ metrics: data.meta.empty_metrics })
        const comparisonValue = getNumericValue(comparisonOuterValue)

        comparisonSeries = {
          comparisonSeriesDefined,
          comparisonValue,
          comparisonOuterValue,
          comparisonTimeLabel
        }
      } else {
        comparisonSeries = { comparisonSeriesDefined }
      }

      if (
        mainSeries.mainSeriesDefined &&
        comparisonSeries.comparisonSeriesDefined &&
        change === null
      ) {
        change = getChange(mainSeries.value, comparisonSeries.comparisonValue)
      }

      return {
        ...mainSeries,
        ...comparisonSeries,
        change
      }
    })

  return {
    remappedData,
    mainSeriesStartEndLabels: [firstTimeLabel, lastTimeLabel],
    comparisonSeriesStartEndLabels: [
      firstComparisonTimeLabel,
      lastComparisonTimeLabel
    ]
  }
}

export const METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS = [
  'bounce_rate',
  'exit_rate',
  'conversion_rate'
  // 'group_conversion_rate'
]

export const getChangeInPercentagePoints = (
  value: number,
  comparisonValue: number
): number => {
  return value - comparisonValue
}

export const getRelativeChange = (
  value: number,
  comparisonValue: number
): number => {
  if (comparisonValue === 0 && value > 0) {
    return 100
  }
  if (comparisonValue === 0 && value === 0) {
    return 0
  }

  return Math.round(((value - comparisonValue) / comparisonValue) * 100)
}

export const REVENUE_METRICS = ['average_revenue', 'total_revenue']

export type LineSegment = {
  startIndexInclusive: number
  stopIndexExclusive: number
  type: 'full' | 'partial'
}

/**
 * Creates segments from points of main series.
 * When a point of data is partial, all lines to and from it must be partial lines.
 * (If that partial point moves, the lines to and from it move.)
 * A full line is drawn only between two or more continuous full periods.
 * No line is drawn from or to gaps in the data.
 */
export function getLineSegments(data: MainSeriesValue[]): LineSegment[] {
  return data.reduce((segments: LineSegment[], curr, i) => {
    if (i === 0) {
      return segments
    }
    const prev = data[i - 1]
    if (!prev.mainSeriesDefined || !curr.mainSeriesDefined) {
      return segments
    }

    const type = prev.isPartial || curr.isPartial ? 'partial' : 'full'
    const lastSegment = segments[segments.length - 1]

    if (lastSegment?.type === type && lastSegment.stopIndexExclusive === i) {
      return [
        ...segments.slice(0, -1),
        { ...lastSegment, stopIndexExclusive: i + 1 }
      ]
    }

    return [
      ...segments,
      { startIndexInclusive: i - 1, stopIndexExclusive: i + 1, type }
    ]
  }, [])
}

/**
 * A data point for the graph and tooltip.
 * It's x position is its index in `GraphDatum[]` array.
 * The values for `value`, `comparisonValue` should be plotted on the y axis, when they are defined for the x position.
 */
export type GraphDatum = {
  change?: number | null
} & MainSeriesValue &
  ComparisonSeriesValue

type MainSeriesValue =
  | { mainSeriesDefined: false }
  | {
      mainSeriesDefined: true
      value: number
      outerValue: RevenueMetricValue | number
      isPartial: boolean
      timeLabel: string
    }

type ComparisonSeriesValue =
  | {
      comparisonSeriesDefined: false
    }
  | {
      comparisonSeriesDefined: true
      comparisonValue: number
      comparisonOuterValue: RevenueMetricValue | number
      comparisonTimeLabel: string
    }
