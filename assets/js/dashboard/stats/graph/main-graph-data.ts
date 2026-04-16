import { MainGraphResponse, MetricValue, ResultItem } from './fetch-main-graph'

/**
 * Fills gaps in @see MainGraphResponse the series of `results` and `comparisonResults`.
 * The BE doesn't return buckets in the series where the value is 0:
 * these need to filled by the FE to have a consistent plot.
 *
 * The assumption is that the two series each are continuously defined.
 *
 * Extracts the numeric values for the series when they are wrapped.
 *
 */
export const remapAndFillData = ({
  data,
  getNumericValue,
  getValue,
  getChange
}: {
  data: MainGraphResponse
  getNumericValue: (metricValue: MetricValue) => number
  getValue: (item: Pick<ResultItem, 'metrics'>) => MetricValue
  getChange: (value: number, comparisonValue: number) => number
}): GraphDatum[] => {
  const totalBucketCount = Math.max(
    data.meta.comparison_time_label_result_indices?.length ?? 0,
    data.meta.time_label_result_indices.length
  )

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

      let main: SeriesValue
      if (typeof timeLabel === 'string') {
        const value =
          indexOfResult !== null
            ? getValue(data.results[indexOfResult]!)
            : getValue({ metrics: data.meta.empty_metrics })
        main = {
          isDefined: true,
          timeLabel,
          value,
          numericValue: getNumericValue(value),
          isPartial: (data.meta.partial_time_labels ?? []).includes(timeLabel),
          isCurrent: data.meta.present_index === index
        }
      } else {
        main = { isDefined: false }
      }

      let comparison: SeriesValue
      if (typeof comparisonTimeLabel === 'string') {
        const value =
          indexOfComparisonResult !== null
            ? getValue(data.comparison_results[indexOfComparisonResult]!)
            : getValue({ metrics: data.meta.empty_metrics })
        comparison = {
          isDefined: true,
          timeLabel: comparisonTimeLabel,
          value,
          numericValue: getNumericValue(value),
          isPartial: (data.meta.comparison_partial_time_labels ?? []).includes(
            comparisonTimeLabel
          ),
          isCurrent: false
        }
      } else {
        comparison = { isDefined: false }
      }

      let change = null

      if (
        change === null &&
        main.isDefined &&
        comparison.isDefined &&
        main.value !== null &&
        comparison.value !== null
      ) {
        change = getChange(main.numericValue, comparison.numericValue)
      }

      return {
        main,
        comparison,
        change
      }
    })

  return remappedData
}

export const getFirstAndLastTimeLabels = (
  response: Pick<MainGraphResponse, 'meta'>,
  series: MainGraphSeriesName
): [string | null, string | null] => {
  const labels = {
    [MainGraphSeriesName.main]: response.meta.time_labels,
    [MainGraphSeriesName.comparison]: response.meta.comparison_time_labels
  }[series]
  if (!labels?.length) {
    return [null, null]
  }
  return [labels[0], labels[labels.length - 1]]
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
  type: 'full' | 'current'
}

/**
 * Creates segments from points of a series.
 *
 * When a point of data is 'current' (only the last point of the series can be),
 * then the line that connects it is dashed. If the 'current' point moves, so
 * does the line connecting it.
 *
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

    const type = curr.isCurrent ? 'current' : 'full'

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
      value: MetricValue
      isPartial: boolean
      isCurrent: boolean
      timeLabel: string
    }
