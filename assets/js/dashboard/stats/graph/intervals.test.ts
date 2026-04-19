import { DEFAULT_SITE } from '../../../../test-utils/app-context-providers'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { getDefaultInterval, validIntervals } from './intervals'
import dayjs from 'dayjs'

const site = DEFAULT_SITE

const noComparison = {
  comparison: null,
  compare_from: null,
  compare_to: null
}

const noCustom = {
  ...noComparison,
  from: null,
  to: null
}

describe(`${validIntervals.name}`, () => {
  describe('fixed periods', () => {
    it('returns [minute] for realtime', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod.realtime, ...noCustom })
      ).toEqual(['minute'])
    })

    it('returns [minute, hour] for day', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod.day, ...noCustom })
      ).toEqual(['minute', 'hour'])
    })

    it('returns [minute, hour] for 24h', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod['24h'], ...noCustom })
      ).toEqual(['minute', 'hour'])
    })

    it('returns [hour, day] for 7d', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod['7d'], ...noCustom })
      ).toEqual(['hour', 'day'])
    })

    it('returns [day, week, month] for 6mo', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod['6mo'], ...noCustom })
      ).toEqual(['day', 'week', 'month'])
    })

    it('returns [day, week, month] for 12mo', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod['12mo'], ...noCustom })
      ).toEqual(['day', 'week', 'month'])
    })

    it('returns [day, week, month] for year', () => {
      expect(
        validIntervals({ site, period: DashboardPeriod.year, ...noCustom })
      ).toEqual(['day', 'week', 'month'])
    })
  })

  describe('custom period', () => {
    it('returns [minute, hour] for one day', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-01-01'),
          ...noComparison
        })
      ).toEqual(['minute', 'hour'])
    })

    it('returns [hour, day] for a range of 7 days', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-01-07'),
          ...noComparison
        })
      ).toEqual(['hour', 'day'])
    })

    it('returns [day, week] for a range of 8 days', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-01-08'),
          ...noComparison
        })
      ).toEqual(['day', 'week'])
    })

    it('returns [day, week] for a range of exactly one month', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-01-31'),
          ...noComparison
        })
      ).toEqual(['day', 'week'])
    })

    it('returns [day, week, month] for a range that barely spans two months', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-02-01'),
          ...noComparison
        })
      ).toEqual(['day', 'week', 'month'])
    })

    it('returns [day, week, month] for a range of exactly one year', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-12-31'),
          ...noComparison
        })
      ).toEqual(['day', 'week', 'month'])
    })

    it('returns [week, month] for a range that exceeds 12 months', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2025-01-01'),
          ...noComparison
        })
      ).toEqual(['week', 'month'])
    })
  })

  describe('custom main vs comparison period', () => {
    it('uses custom comparison range when it is coarser than the custom main range', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-06-01'),
          to: dayjs('2024-06-02'),
          comparison: ComparisonMode.custom,
          compare_from: dayjs('2023-01-01'),
          compare_to: dayjs('2024-01-01')
        })
      ).toEqual(['week', 'month'])
    })

    it('uses custom main range when it is coarser than the custom comparison range', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2023-01-01'),
          to: dayjs('2024-01-01'),
          comparison: ComparisonMode.custom,
          compare_from: dayjs('2024-06-01'),
          compare_to: dayjs('2024-06-02')
        })
      ).toEqual(['week', 'month'])
    })

    it('uses custom comparison range when it is coarser than the fixed main period', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod.day,
          from: null,
          to: null,
          comparison: ComparisonMode.custom,
          compare_from: dayjs('2023-01-01'),
          compare_to: dayjs('2024-01-01')
        })
      ).toEqual(['week', 'month'])
    })

    it('uses fixed main period when it is coarser than the custom comparison period', () => {
      expect(
        validIntervals({
          site,
          period: DashboardPeriod['12mo'],
          from: null,
          to: null,
          comparison: ComparisonMode.custom,
          compare_from: dayjs('2024-01-01'),
          compare_to: dayjs('2024-01-01')
        })
      ).toEqual(['day', 'week', 'month'])
    })
  })
})

describe(`${getDefaultInterval.name}`, () => {
  describe('fixed periods', () => {
    it('returns hour for day', () => {
      expect(
        getDefaultInterval({ site, period: DashboardPeriod.day, ...noCustom })
      ).toBe('hour')
    })

    it('returns hour for 24h', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod['24h'],
          ...noCustom
        })
      ).toBe('hour')
    })

    it('returns day for 7d', () => {
      expect(
        getDefaultInterval({ site, period: DashboardPeriod['7d'], ...noCustom })
      ).toBe('day')
    })

    it('returns month for 6mo', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod['6mo'],
          ...noCustom
        })
      ).toBe('month')
    })

    it('returns month for 12mo', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod['12mo'],
          ...noCustom
        })
      ).toBe('month')
    })

    it('returns month for year', () => {
      expect(
        getDefaultInterval({ site, period: DashboardPeriod.year, ...noCustom })
      ).toBe('month')
    })
  })

  describe('custom period', () => {
    it('returns hour for a single date', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-01-01'),
          ...noComparison
        })
      ).toBe('hour')
    })

    it('returns day for a range under 30 days', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-01-20'),
          ...noComparison
        })
      ).toBe('day')
    })

    it('returns week for a range below 6 months', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2024-01-01'),
          to: dayjs('2024-05-31'),
          ...noComparison
        })
      ).toBe('week')
    })

    it('returns month for a range that barely spans 7 months', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod.custom,
          from: dayjs('2023-01-01'),
          to: dayjs('2023-07-01'),
          ...noComparison
        })
      ).toBe('month')
    })

    it('returns day for a fixed 7d period even when comparing with a whole year', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod['7d'],
          from: null,
          to: null,
          comparison: ComparisonMode.custom,
          compare_from: dayjs('2024-01-01'),
          compare_to: dayjs('2024-12-01')
        })
      ).toBe('day')
    })

    it('returns default for comparison range instead when default for main is not appropriate', () => {
      expect(
        getDefaultInterval({
          site,
          period: DashboardPeriod.day,
          from: null,
          to: null,
          comparison: ComparisonMode.custom,
          compare_from: dayjs('2024-01-01'),
          compare_to: dayjs('2024-12-31')
        })
      ).toBe('month')
    })
  })
})
