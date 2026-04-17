import { PlausibleSite } from '../../site-context'
import { DashboardState } from '../../dashboard-state'
import { Dayjs } from 'dayjs'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { dateForSite, nowForSite } from '../../util/date'

export type Interval = 'minute' | 'hour' | 'day' | 'week' | 'month'

export type GetIntervalProps = { site: PlausibleSite } & Pick<
  DashboardState,
  'period' | 'to' | 'from' | 'comparison' | 'compare_to' | 'compare_from'
>

type DayjsRange = { from: Dayjs; to: Dayjs }

type FixedPeriod = Exclude<DashboardPeriod, 'custom' | 'all'>

const VALID_INTERVALS_BY_FIXED_PERIOD: Record<FixedPeriod, Interval[]> = {
  realtime: ['minute'],
  realtime_30m: ['minute'],
  day: ['minute', 'hour'],
  '24h': ['minute', 'hour'],
  '7d': ['hour', 'day'],
  '28d': ['day', 'week'],
  '30d': ['day', 'week'],
  '91d': ['day', 'week', 'month'],
  month: ['day', 'week'],
  '6mo': ['day', 'week', 'month'],
  '12mo': ['day', 'week', 'month'],
  year: ['day', 'week', 'month']
}

const INTERVAL_COARSENESS: Record<Interval, number> = {
  minute: 0,
  hour: 1,
  day: 2,
  week: 3,
  month: 4
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
    return mainIntervals.includes('day') ? 'day' : 'month'
  }

  switch (period) {
    case 'day':
      return 'hour'
    case '24h':
      return 'hour'
    case '7d':
      return 'day'
    case '6mo':
      return 'month'
    case '12mo':
      return 'month'
    case 'year':
      return 'month'
    default:
      return VALID_INTERVALS_BY_FIXED_PERIOD[period as FixedPeriod][0]
  }
}

function validIntervalsForCustomPeriod({ to, from }: DayjsRange): Interval[] {
  if (to.diff(from, 'days') < 7) {
    return ['day']
  }
  if (to.diff(from, 'months') < 1) {
    return ['day', 'week']
  }
  if (to.diff(from, 'months') < 12) {
    return ['day', 'week', 'month']
  }
  return ['week', 'month']
}

function validIntervalsForAllTimePeriod(site: PlausibleSite): Interval[] {
  const to = nowForSite(site)
  const from = site.statsBegin ? dateForSite(site.statsBegin, site) : to

  return validIntervalsForCustomPeriod({ from, to })
}

function defaultForCustomPeriod({ from, to }: DayjsRange): Interval {
  if (to.diff(from, 'days') < 30) {
    return 'day'
  } else if (to.diff(from, 'months') < 6) {
    return 'week'
  } else {
    return 'month'
  }
}
