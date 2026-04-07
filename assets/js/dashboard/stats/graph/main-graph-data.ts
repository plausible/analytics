import { Metric } from '../../../types/query-api'
import { MainGraphResponse } from './fetch-main-graph'

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
 * - whether there's a slice at the very end of main series that is partial (used for explaining the drop at the end of the graph).
 *
 */
export const remapAndFillData = ({
  data,
  metric
}: {
  data: MainGraphResponse
  metric: Metric
}): {
  remappedData: GraphDatum[]
  yMax: number
  mainSeriesStartEndLabels: [string | null, string | null]
  comparisonSeriesStartEndLabels: [string | null, string | null]
} => {
  const totalBucketCount = Math.max(
    data.meta.comparison_time_label_result_indices?.length ?? 0,
    data.meta.time_label_result_indices.length
  )

  let yMax: number = 1
  let firstTimeLabel: null | string = null
  let lastTimeLabel: null | string = null

  let firstComparisonTimeLabel: null | string = null
  let lastComparisonTimeLabel: null | string = null

  const remappedData: GraphDatum[] = new Array(totalBucketCount)
    .fill(null)
    .map((_, index) => {
      const [
        timeLabel,
        indexOfResult,
        comparisonTimeLabel,
        indexOfComparisonResult
      ] = [
        data.meta.time_labels[index] ?? null,
        data.meta.time_label_result_indices[index] ?? null,
        (data.meta.comparison_time_labels &&
          data.meta.comparison_time_labels[index]) ??
          null,
        (data.meta.comparison_time_label_result_indices &&
          data.meta.comparison_time_label_result_indices[index]) ??
          null
      ]

      const mainSeriesDefined = typeof timeLabel === 'string'
      const comparisonSeriesDefined = typeof comparisonTimeLabel === 'string'

      let isPartial: boolean | null = null
      let value: number | null = null

      if (mainSeriesDefined) {
        isPartial = (data.meta.partial_time_labels ?? []).find(
          (l) => l === timeLabel
        )
          ? true
          : false

        if (firstTimeLabel === null) {
          firstTimeLabel = timeLabel
        }

        lastTimeLabel = timeLabel

        if (indexOfResult !== null) {
          const row = data.results[indexOfResult]
          const [unparsedValue] = row!.metrics!
          if (unparsedValue === null) {
            value = 0
          } else if (
            typeof unparsedValue === 'object' &&
            unparsedValue.hasOwnProperty('value')
          ) {
            value = unparsedValue.value
          } else if (typeof unparsedValue === 'number') {
            value = unparsedValue
          }
        } else {
          value = 0
        }
      }
      if (value !== null && value > yMax) {
        yMax = value
      }
      let change = null
      let comparisonValue = null
      if (comparisonSeriesDefined) {
        if (firstComparisonTimeLabel === null) {
          firstComparisonTimeLabel = comparisonTimeLabel
        }

        lastComparisonTimeLabel = comparisonTimeLabel

        if (indexOfComparisonResult !== null) {
          const row = data.comparison_results[indexOfComparisonResult]
          const [unparsedValue] = row!.metrics!

          if (unparsedValue === null) {
            comparisonValue = 0
          } else if (
            typeof unparsedValue === 'object' &&
            unparsedValue.hasOwnProperty('value')
          ) {
            comparisonValue = unparsedValue.value
          } else if (typeof unparsedValue === 'number') {
            comparisonValue = unparsedValue
            change = row!.change !== null ? row!.change[0] : null
          }
        } else {
          comparisonValue = 0
        }
      }

      if (comparisonValue !== null && comparisonValue > yMax) {
        yMax = comparisonValue
      }

      if (mainSeriesDefined && comparisonSeriesDefined && change === null) {
        change = METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS.includes(metric)
          ? getChangeInPercentagePoints(value!, comparisonValue!)
          : getRelativeChange(value!, comparisonValue!)
      }

      return {
        value,
        comparisonValue,
        timeLabel,
        comparisonTimeLabel,
        change,
        isPartial
      } as GraphDatum
    })

  return {
    remappedData,
    yMax,
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

export type LineSegment = {
  startIndexInclusive: number
  stopIndexExclusive: number
  type: 'full' | 'partial'
}

// Computes drawable line segments from a series of points.
// A segment's dash style is determined by its edges: dashed if either endpoint
// is partial, solid if both are non-partial. Boundary points between a solid
// and a dashed segment are shared (appear as the end of one and start of the next).
export function getLineSegments(data: MainSeriesValue[]): LineSegment[] {
  return data.reduce((segments: LineSegment[], point, i) => {
    if (i === 0) {
      return segments
    }
    const prev = data[i - 1]
    if (prev.value === null || point.value === null) {
      return segments
    }

    const type = prev.isPartial || point.isPartial ? 'partial' : 'full'
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

type NotDefinedValue = { value: null; isPartial: null; timeLabel: null }
type DefinedValue = { value: number; isPartial: boolean; timeLabel: string }
type MainSeriesValue = NotDefinedValue | DefinedValue

type NotDefinedComparisonValue = {
  comparisonValue: null
  isPartial: null
  comparisonTimeLabel: null
}
type DefinedComparisonValue = {
  comparisonValue: number
  comparisonTimeLabel: string
}
type ComparisonSeriesValue = NotDefinedComparisonValue | DefinedComparisonValue
