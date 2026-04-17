import { PlausibleSite } from '../../site-context'
import { DashboardState } from '../../dashboard-state'
import { Dayjs } from 'dayjs'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { dateForSite, nowForSite } from '../../util/date'

export enum Interval {
  minute = 'minute',
  hour = 'hour',
  day = 'day',
  week = 'week',
  month = 'month'
}

export type GetIntervalProps = { site: PlausibleSite } & Pick<
  DashboardState,
  'period' | 'to' | 'from' | 'comparison' | 'compare_to' | 'compare_from'
>

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

function max_coarseness(intervals: Interval[]): number {
  return Math.max(...intervals.map((i) => INTERVAL_COARSENESS[i]))
}

function coarser(a: Interval[], b: Interval[]): Interval[] {
  return max_coarseness(a) >= max_coarseness(b) ? a : b
}

function validIntervalsForMainPeriod(
  site: PlausibleSite,
  period: DashboardPeriod,
  from: Dayjs | null,
  to: Dayjs | null
): Interval[] {
  if (period === DashboardPeriod.custom && from && to) {
    return validIntervalsForCustomPeriod({ from, to })
  }
  if (period === 'all') {
    return validIntervalsForAllTimePeriod(site)
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

export function validIntervals({
  site,
  period,
  to,
  from,
  comparison,
  compare_to,
  compare_from
}: GetIntervalProps): Interval[] {
  const mainIntervals = validIntervalsForMainPeriod(site, period, from, to)
  const comparisonIntervals = validIntervalsForCustomComparison(
    comparison,
    compare_from,
    compare_to
  )
  return comparisonIntervals
    ? coarser(mainIntervals, comparisonIntervals)
    : mainIntervals
}

export function getDefaultInterval({
  site,
  period,
  to,
  from,
  comparison,
  compare_to,
  compare_from
}: GetIntervalProps): Interval {
  const mainIntervals = validIntervalsForMainPeriod(site, period, from, to)
  const comparisonIntervals = validIntervalsForCustomComparison(
    comparison,
    compare_from,
    compare_to
  )

  if (
    comparisonIntervals &&
    max_coarseness(comparisonIntervals) > max_coarseness(mainIntervals)
  ) {
    return defaultForCustomPeriod({ from: compare_from!, to: compare_to! })
  }

  if (period === DashboardPeriod.custom && from && to) {
    return defaultForCustomPeriod({ from, to })
  }

  if (period === 'all') {
    return mainIntervals.includes(Interval.day) ? Interval.day : Interval.month
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
  if (to.diff(from, 'days') < 7) {
    return [Interval.day]
  }
  if (to.diff(from, 'months') < 1) {
    return [Interval.day, Interval.week]
  }
  if (to.diff(from, 'months') < 12) {
    return [Interval.day, Interval.week, Interval.month]
  }
  return [Interval.week, Interval.month]
}

function validIntervalsForAllTimePeriod(site: PlausibleSite): Interval[] {
  const to = nowForSite(site)
  const from = site.statsBegin ? dateForSite(site.statsBegin, site) : to

  return validIntervalsForCustomPeriod({ from, to })
}

function defaultForCustomPeriod({ from, to }: DayjsRange): Interval {
  if (to.diff(from, 'days') < 30) {
    return Interval.day
  } else if (to.diff(from, 'months') < 6) {
    return Interval.week
  } else {
    return Interval.month
  }
}
