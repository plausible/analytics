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

      const getSeriesValue = ({
        timeLabel,
        indexOfResult,
        results,
        partialTimeLabels
      }: {
        timeLabel: string
        indexOfResult: number | null
        results: Array<ResultItem | null>
        partialTimeLabels: string[]
      }): SeriesValue => {
        const isPartial = partialTimeLabels.find((l) => l === timeLabel)
          ? true
          : false

        const value =
          indexOfResult !== null
            ? getValue(results[indexOfResult]!)
            : getValue({ metrics: data.meta.empty_metrics })

        return {
          isDefined: true,
          value,
          numericValue: getNumericValue(value),
          isPartial,
          timeLabel
        }
      }

      const main: SeriesValue =
        typeof timeLabel === 'string'
          ? getSeriesValue({
              timeLabel,
              partialTimeLabels: data.meta.partial_time_labels ?? [],
              results: data.results,
              indexOfResult: indexOfResult
            })
          : { isDefined: false }
      if (main.isDefined) {
        firstTimeLabel =
          firstTimeLabel === null ? main.timeLabel : firstTimeLabel
        lastTimeLabel = timeLabel
      }

      const comparison: SeriesValue =
        typeof comparisonTimeLabel === 'string'
          ? getSeriesValue({
              timeLabel: comparisonTimeLabel,
              partialTimeLabels: data.meta.comparison_partial_time_labels ?? [],
              results: data.comparison_results,
              indexOfResult: indexOfComparisonResult
            })
          : { isDefined: false }
      if (comparison.isDefined) {
        firstComparisonTimeLabel =
          firstComparisonTimeLabel === null
            ? comparison.timeLabel
            : firstComparisonTimeLabel
        lastComparisonTimeLabel = comparison.timeLabel
      }

      let change = null

      if (main.isDefined && comparison.isDefined && change === null) {
        change = getChange(main.numericValue, comparison.numericValue)
      }

      return {
        main: main,
        comparison: comparison,
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
export function getLineSegments(data: SeriesValue[]): LineSegment[] {
  return data.reduce((segments: LineSegment[], curr, i) => {
    if (i === 0) {
      return segments
    }
    const prev = data[i - 1]
    if (!prev.isDefined || !curr.isDefined) {
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
 * The values for `numericValue`, `comparisonNumericValue` should be plotted on the y axis, when they are defined for the x position.
 */
export type GraphDatum = Record<MainGraphSeriesName, SeriesValue> & {
  change?: number | null
}

export enum MainGraphSeriesName {
  main = 'main',
  comparison = 'comparison'
}

type SeriesValue =
  | { isDefined: false }
  | {
      isDefined: true
      numericValue: number
      value: RevenueMetricValue | number
      isPartial: boolean
      timeLabel: string
    }
