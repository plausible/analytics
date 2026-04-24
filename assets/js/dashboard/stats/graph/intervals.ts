import { Dayjs } from 'dayjs'
import {
  ComparisonMode,
  DashboardPeriod,
  DashboardTimeSettings
} from '../../dashboard-time-periods'
import { now, parseUTCDate } from '../../util/date'

export enum Interval {
  minute = 'minute',
  hour = 'hour',
  day = 'day',
  week = 'week',
  month = 'month'
}

export type GetIntervalProps = Omit<DashboardTimeSettings, 'date'>

type DayjsRange = { from: Dayjs; to: Dayjs }

type FixedPeriod = Exclude<DashboardPeriod, 'custom' | 'all'>

const VALID_INTERVALS_BY_FIXED_PERIOD: Record<FixedPeriod, Interval[]> = {
  realtime: [Interval.minute],
  realtime_30m: [Interval.minute],
  day: [Interval.minute, Interval.hour],
  '24h': [Interval.minute, Interval.hour],
  '7d': [Interval.hour, Interval.day],
  '28d': [Interval.day, Interval.week],
  '30d': [Interval.day, Interval.week],
  '91d': [Interval.day, Interval.week, Interval.month],
  month: [Interval.day, Interval.week],
  '6mo': [Interval.day, Interval.week, Interval.month],
  '12mo': [Interval.day, Interval.week, Interval.month],
  year: [Interval.day, Interval.week, Interval.month]
}

const INTERVAL_COARSENESS: Record<Interval, number> = {
  [Interval.minute]: 0,
  [Interval.hour]: 1,
  [Interval.day]: 2,
  [Interval.week]: 3,
  [Interval.month]: 4
}

/**
 * Returns the intervals available for the current dashboard state.
 *
 * When a custom comparison period is active, the valid intervals for both the
 * main period and the comparison period are computed independently and the
 * coarser set is returned — ensuring the chosen interval is granular enough to
 * be meaningful for whichever date range is longer. For all other comparison
 * modes the valid intervals are determined solely by the main period.
 */
export function validIntervals({
  siteTimezoneOffset,
  siteStatsBegin,
  period,
  to,
  from,
  comparison,
  compare_to,
  compare_from
}: GetIntervalProps): Interval[] {
  const mainIntervals = validIntervalsForMainPeriod(
    siteTimezoneOffset,
    siteStatsBegin,
    period,
    from,
    to
  )
  const comparisonIntervals = validIntervalsForCustomComparison(
    comparison,
    compare_from,
    compare_to
  )
  return comparisonIntervals
    ? coarser(mainIntervals, comparisonIntervals)
    : mainIntervals
}

/**
 * Returns the default interval for the current dashboard state.
 *
 * The default is always derived from the main period. The only exception is
 * when a custom comparison period is active and that period does not support
 * the main-period default — in that case the default falls back to whatever is
 * appropriate for the comparison date range.
 */
export function getDefaultInterval({
  siteTimezoneOffset,
  siteStatsBegin,
  period,
  to,
  from,
  comparison,
  compare_to,
  compare_from
}: GetIntervalProps): Interval {
  const defaultForMain = defaultForMainPeriod(
    siteTimezoneOffset,
    siteStatsBegin,
    period,
    from,
    to
  )

  const validComparisonIntervals = validIntervalsForCustomComparison(
    comparison,
    compare_from,
    compare_to
  )

  if (
    !validComparisonIntervals ||
    validComparisonIntervals.includes(defaultForMain)
  ) {
    return defaultForMain
  } else {
    return defaultForCustomPeriod({ from: compare_from!, to: compare_to! })
  }
}

function max_coarseness(intervals: Interval[]): number {
  return Math.max(...intervals.map((i) => INTERVAL_COARSENESS[i]))
}

function coarser(a: Interval[], b: Interval[]): Interval[] {
  return max_coarseness(a) >= max_coarseness(b) ? a : b
}

function validIntervalsForMainPeriod(
  siteTimezoneOffset: DashboardTimeSettings['siteTimezoneOffset'],
  siteStatsBegin: DashboardTimeSettings['siteStatsBegin'],
  period: DashboardPeriod,
  from: Dayjs | null,
  to: Dayjs | null
): Interval[] {
  if (period === DashboardPeriod.custom && from && to) {
    return validIntervalsForCustomPeriod({ from, to })
  }
  if (period === 'all') {
    return validIntervalsForAllTimePeriod(siteTimezoneOffset, siteStatsBegin)
  }
  return VALID_INTERVALS_BY_FIXED_PERIOD[period as FixedPeriod]
}

function validIntervalsForCustomComparison(
  comparison: ComparisonMode | null,
  compare_from: Dayjs | null,
  compare_to: Dayjs | null
): Interval[] | null {
  if (comparison === ComparisonMode.custom && compare_from && compare_to) {
    return validIntervalsForCustomPeriod({ from: compare_from, to: compare_to })
  }
  return null
}

function defaultForMainPeriod(
  siteTimezoneOffset: DashboardTimeSettings['siteTimezoneOffset'],
  siteStatsBegin: DashboardTimeSettings['siteStatsBegin'],
  period: DashboardPeriod,
  from: Dayjs | null,
  to: Dayjs | null
): Interval {
  if (period === DashboardPeriod.custom && from && to) {
    return defaultForCustomPeriod({ from, to })
  }
  if (period === 'all') {
    return validIntervalsForAllTimePeriod(
      siteTimezoneOffset,
      siteStatsBegin
    ).includes(Interval.day)
      ? Interval.day
      : Interval.month
  }

  switch (period) {
    case 'day':
      return Interval.hour
    case '24h':
      return Interval.hour
    case '7d':
      return Interval.day
    case '6mo':
      return Interval.month
    case '12mo':
      return Interval.month
    case 'year':
      return Interval.month
    default:
      return VALID_INTERVALS_BY_FIXED_PERIOD[period as FixedPeriod][0]
  }
}

function validIntervalsForCustomPeriod({ to, from }: DayjsRange): Interval[] {
  if (to.diff(from, 'days') < 1) {
    return [Interval.minute, Interval.hour]
  }
  if (to.diff(from, 'days') < 7) {
    return [Interval.hour, Interval.day]
  }
  if (to.diff(from, 'months') < 1) {
    return [Interval.day, Interval.week]
  }
  if (to.diff(from, 'months') < 12) {
    return [Interval.day, Interval.week, Interval.month]
  }
  return [Interval.week, Interval.month]
}

function validIntervalsForAllTimePeriod(
  siteTimezoneOffset: DashboardTimeSettings['siteTimezoneOffset'],
  siteStatsBegin: DashboardTimeSettings['siteStatsBegin']
): Interval[] {
  const to = now(siteTimezoneOffset)
  const from = siteStatsBegin
    ? parseUTCDate(siteStatsBegin).utcOffset(siteTimezoneOffset / 60, true)
    : to

  return validIntervalsForCustomPeriod({ from, to })
}

function defaultForCustomPeriod({ from, to }: DayjsRange): Interval {
  if (to.diff(from, 'days') < 1) {
    return Interval.hour
  } else if (to.diff(from, 'days') < 30) {
    return Interval.day
  } else if (to.diff(from, 'months') < 6) {
    return Interval.week
  } else {
    return Interval.month
  }
}
