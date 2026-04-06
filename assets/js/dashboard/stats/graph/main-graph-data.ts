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
  startOfLastPartialSlice: null | number
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

  let startOfLastPartialSlice: null | number = null

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

        if (isPartial) {
          startOfLastPartialSlice = index
        } else {
          // if there is a full period after a partial slice,
          // it's not a partial slice anchored at the end of the series
          startOfLastPartialSlice = null
        }

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
      }
    })

  return {
    startOfLastPartialSlice,
    remappedData,
    yMax,
    mainSeriesStartEndLabels: [firstTimeLabel, lastTimeLabel],
    comparisonSeriesStartEndLabels: [
      firstComparisonTimeLabel,
      lastComparisonTimeLabel
    ]
  }
}

const METRICS_WITH_CHANGE_IN_PERCENTAGE_POINTS = [
  'bounce_rate',
  'exit_rate',
  'conversion_rate',
  'group_conversion_rate'
]

const getChangeInPercentagePoints = (
  value: number,
  comparisonValue: number
): number => {
  return value - comparisonValue
}

const getRelativeChange = (value: number, comparisonValue: number): number => {
  if (comparisonValue === 0 && value > 0) {
    return 100
  }
  if (comparisonValue === 0 && value === 0) {
    return 0
  }

  return Math.round(((value - comparisonValue) / comparisonValue) * 100)
}

/**
 * A data point for the graph and tooltip.
 * It's x position is its index in `GraphDatum[]` array.
 * The values for `value`, `comparisonValue` should be plotted on the y axis, when they are defined for the x position.
 */
type GraphDatum = {
  /** When `value` is null, it means the main series isn't defined in this x position */
  value: number | null
  timeLabel: string | null
  isPartial: boolean | null
  /** When `comparisonValue` is null, it means the comparison series isn't defined in this x position */
  comparisonValue?: number | null
  comparisonTimeLabel?: string | null
  change?: number | null
}
