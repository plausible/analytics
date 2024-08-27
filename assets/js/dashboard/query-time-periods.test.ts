/** @format */

import {
  ComparisonMode,
  getDashboardTimeSettings,
  getPeriodStorageKey,
  getStoredPeriod,
  QueryPeriod
} from './query-time-periods'

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
  const defaultValues = {
    period: QueryPeriod['7d'],
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
        searchValues: emptySearchValues,
        storedValues: emptyStoredValues,
        defaultValues
      })
    ).toEqual(defaultValues)
  })

  it('returns stored values if no search', () => {
    expect(
      getDashboardTimeSettings({
        searchValues: emptySearchValues,
        storedValues: {
          period: QueryPeriod['12mo'],
          comparison: ComparisonMode.year_over_year,
          match_day_of_week: false
        },
        defaultValues
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
        defaultValues
      })
    ).toEqual({
      period: QueryPeriod['year'],
      comparison: null,
      match_day_of_week: true
    })
  })
})
