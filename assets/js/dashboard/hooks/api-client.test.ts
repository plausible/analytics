import { ComparisonMode, DashboardPeriod } from '../dashboard-time-periods'
import { formatISO, utcNow } from '../util/date'
import {
  CACHE_TTL_HISTORICAL,
  CACHE_TTL_LONG_ONGOING,
  CACHE_TTL_REALTIME,
  CACHE_TTL_SHORT_ONGOING,
  getStaleTime
} from './api-client'

const today = utcNow()
const yesterday = utcNow().subtract(1, 'day')

const noComparison = { comparison: null, compare_from: null, compare_to: null }
const base = {
  siteStatsBegin: '',
  siteTimezoneOffset: 0,
  date: null,
  from: null,
  to: null,
  ...noComparison
}

describe(`${getStaleTime.name}`, () => {
  describe('realtime periods', () => {
    test('for realtime', () => {
      expect(getStaleTime({ ...base, period: DashboardPeriod.realtime })).toBe(
        CACHE_TTL_REALTIME
      )
    })

    test('for realtime_30m', () => {
      expect(
        getStaleTime({ ...base, period: DashboardPeriod.realtime_30m })
      ).toBe(CACHE_TTL_REALTIME)
    })
  })

  describe('historical periods (does not include today)', () => {
    test('for 28d', () => {
      expect(getStaleTime({ ...base, period: DashboardPeriod['28d'] })).toBe(
        CACHE_TTL_HISTORICAL
      )
    })

    test('for 6mo', () => {
      expect(getStaleTime({ ...base, period: DashboardPeriod['6mo'] })).toBe(
        CACHE_TTL_HISTORICAL
      )
    })

    test('for period=day and date=yesterday', () => {
      expect(
        getStaleTime({ ...base, period: DashboardPeriod.day, date: yesterday })
      ).toBe(CACHE_TTL_HISTORICAL)
    })

    test('for custom period ending yesterday', () => {
      expect(
        getStaleTime({
          ...base,
          period: DashboardPeriod.custom,
          from: yesterday.subtract(7, 'day'),
          to: yesterday,
          ...noComparison
        })
      ).toBe(CACHE_TTL_HISTORICAL)
    })
  })

  describe('ongoing periods with short TTL (supports day or shorter interval)', () => {
    test('for today period', () => {
      expect(getStaleTime({ ...base, period: DashboardPeriod.day })).toBe(
        CACHE_TTL_SHORT_ONGOING
      )
    })

    test('for 24h period', () => {
      expect(getStaleTime({ ...base, period: DashboardPeriod['24h'] })).toBe(
        CACHE_TTL_SHORT_ONGOING
      )
    })

    test('for period=month and date=today', () => {
      expect(
        getStaleTime({ ...base, period: DashboardPeriod.month, date: today })
      ).toBe(CACHE_TTL_SHORT_ONGOING)
    })

    test('for period=year and date=today', () => {
      expect(
        getStaleTime({ ...base, period: DashboardPeriod.year, date: today })
      ).toBe(CACHE_TTL_SHORT_ONGOING)
    })

    test('for custom period under 12 months ending today', () => {
      expect(
        getStaleTime({
          ...base,
          period: DashboardPeriod.custom,
          from: today.subtract(6, 'month'),
          to: today
        })
      ).toBe(CACHE_TTL_SHORT_ONGOING)
    })

    test('for all time period when stats begin recently', () => {
      expect(
        getStaleTime({
          ...base,
          siteStatsBegin: formatISO(yesterday),
          period: DashboardPeriod.all
        })
      ).toBe(CACHE_TTL_SHORT_ONGOING)
    })

    test('for a historical period when comparison includes today', () => {
      expect(
        getStaleTime({
          ...base,
          period: DashboardPeriod['28d'],
          date: today,
          comparison: ComparisonMode.custom,
          compare_from: yesterday.subtract(28, 'day'),
          compare_to: today
        })
      ).toBe(CACHE_TTL_SHORT_ONGOING)
    })
  })

  describe('ongoing periods with long TTL (only week or month interval available)', () => {
    test('for custom period over 12 months ending today', () => {
      expect(
        getStaleTime({
          ...base,
          period: DashboardPeriod.custom,
          from: today.subtract(13, 'month'),
          to: today
        })
      ).toBe(CACHE_TTL_LONG_ONGOING)
    })

    test('for all time period when stats begin over 12 months ago', () => {
      expect(
        getStaleTime({
          ...base,
          siteStatsBegin: '2020-01-01',
          period: DashboardPeriod.all
        })
      ).toBe(CACHE_TTL_LONG_ONGOING)
    })
  })
})
