import { defaultSite } from '../../test-utils/app-context-providers'
import {
  ComparisonMode,
  getDashboardTimeSettings,
  getPeriodStorageKey,
  getStoredPeriod,
  QueryPeriod
} from './query-time-periods'
import { formatISO, utcNow } from './util/date'

describe(`${getStoredPeriod.name}`, () => {
  const domain = 'any.site'
  const key = getPeriodStorageKey(domain)

  it('returns fallback value if invalid values stored', () => {
    localStorage.setItem(key, 'any-invalid-value')
    expect(getStoredPeriod(domain, null)).toEqual(null)
  })

  it('returns correct value if value stored', () => {
    localStorage.setItem(key, QueryPeriod['7d'])
    expect(getStoredPeriod(domain, null)).toEqual(QueryPeriod['7d'])
  })
})

describe(`${getDashboardTimeSettings.name}`, () => {
  const site = defaultSite

  const defaultValues = {
    period: QueryPeriod['28d'],
    comparison: null,
    match_day_of_week: true
  }
  const emptySearchValues = {
    period: undefined,
    comparison: undefined,
    match_day_of_week: undefined
  }
  const emptyStoredValues = {
    period: null,
    comparison: null,
    match_day_of_week: null
  }

  it('returns defaults if nothing stored and no search', () => {
    expect(
      getDashboardTimeSettings({
        site: site,
        searchValues: emptySearchValues,
        storedValues: emptyStoredValues,
        defaultValues,
        segmentIsExpanded: false
      })
    ).toEqual(defaultValues)
  })

  it('defaults period to today if the site was created today', () => {
    expect(
      getDashboardTimeSettings({
        site: { ...site, nativeStatsBegin: formatISO(utcNow()) },
        searchValues: emptySearchValues,
        storedValues: emptyStoredValues,
        defaultValues,
        segmentIsExpanded: false
      })
    ).toEqual({ ...defaultValues, period: 'day' })
  })

  it('defaults period to today if the site was created yesterday', () => {
    expect(
      getDashboardTimeSettings({
        site: {
          ...site,
          nativeStatsBegin: formatISO(utcNow().subtract(1, 'day'))
        },
        searchValues: emptySearchValues,
        storedValues: emptyStoredValues,
        defaultValues,
        segmentIsExpanded: false
      })
    ).toEqual({ ...defaultValues, period: 'day' })
  })

  it('returns stored values if no search', () => {
    expect(
      getDashboardTimeSettings({
        site: site,
        searchValues: emptySearchValues,
        storedValues: {
          period: QueryPeriod['12mo'],
          comparison: ComparisonMode.year_over_year,
          match_day_of_week: false
        },
        defaultValues,
        segmentIsExpanded: false
      })
    ).toEqual({
      period: QueryPeriod['12mo'],
      comparison: ComparisonMode.year_over_year,
      match_day_of_week: false
    })
  })

  it('uses values from search above all else, treats ComparisonMode.off as null', () => {
    expect(
      getDashboardTimeSettings({
        site: site,
        searchValues: {
          period: QueryPeriod['year'],
          comparison: ComparisonMode.off,
          match_day_of_week: true
        },
        storedValues: {
          period: QueryPeriod['12mo'],
          comparison: ComparisonMode.year_over_year,
          match_day_of_week: false
        },
        defaultValues,
        segmentIsExpanded: false
      })
    ).toEqual({
      period: QueryPeriod['year'],
      comparison: null,
      match_day_of_week: true
    })
  })

  it('respects segmentIsExpanded: true option: comparison and edit segment mode are mutually exclusive', () => {
    expect(
      getDashboardTimeSettings({
        site: site,
        searchValues: {
          period: QueryPeriod['custom'],
          comparison: ComparisonMode.previous_period,
          match_day_of_week: true
        },
        storedValues: emptyStoredValues,
        defaultValues,
        segmentIsExpanded: true
      })
    ).toEqual({
      period: QueryPeriod['custom'],
      comparison: null,
      match_day_of_week: true
    })
  })
})
