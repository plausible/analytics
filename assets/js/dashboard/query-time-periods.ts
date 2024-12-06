/* @format */
import { useEffect } from 'react'
import {
  clearedComparisonSearch,
  clearedDateSearch,
  DashboardQuery
} from './query'
import { PlausibleSite, useSiteContext } from './site-context'
import {
  formatDateRange,
  formatDay,
  formatISO,
  formatMonthYYYY,
  formatYear,
  isSameDate,
  isSameMonth,
  isThisMonth,
  isThisYear,
  isToday,
  lastMonth,
  nowForSite,
  parseNaiveDate,
  yesterday
} from './util/date'
import { AppNavigationTarget } from './navigation/use-app-navigate'
import { getDomainScopedStorageKey, getItem, setItem } from './util/storage'
import { useQueryContext } from './query-context'

export enum QueryPeriod {
  'realtime' = 'realtime',
  'day' = 'day',
  'month' = 'month',
  '7d' = '7d',
  '30d' = '30d',
  '6mo' = '6mo',
  '12mo' = '12mo',
  'year' = 'year',
  'all' = 'all',
  'custom' = 'custom'
}

export enum ComparisonMode {
  off = 'off',
  previous_period = 'previous_period',
  year_over_year = 'year_over_year',
  custom = 'custom'
}

export const COMPARISON_MODES = {
  [ComparisonMode.off]: 'Disable comparison',
  [ComparisonMode.previous_period]: 'Previous period',
  [ComparisonMode.year_over_year]: 'Year over year',
  [ComparisonMode.custom]: 'Custom period'
}

export enum ComparisonMatchMode {
  MatchExactDate = 0,
  MatchDayOfWeek = 1
}

export const COMPARISON_MATCH_MODE_LABELS = {
  [ComparisonMatchMode.MatchDayOfWeek]: 'Match day of week',
  [ComparisonMatchMode.MatchExactDate]: 'Match exact date'
}

export const DEFAULT_COMPARISON_MODE = ComparisonMode.previous_period

export const COMPARISON_DISABLED_PERIODS = [
  QueryPeriod.realtime,
  QueryPeriod.all
]

export const DEFAULT_COMPARISON_MATCH_MODE = ComparisonMatchMode.MatchDayOfWeek

export function getPeriodStorageKey(domain: string): string {
  return getDomainScopedStorageKey('period', domain)
}

export function isValidPeriod(period: unknown): period is QueryPeriod {
  return Object.values<unknown>(QueryPeriod).includes(period)
}

export function getStoredPeriod(
  domain: string,
  fallbackValue: QueryPeriod | null
) {
  const item = getItem(getPeriodStorageKey(domain))
  return isValidPeriod(item) ? item : fallbackValue
}

function storePeriod(domain: string, value: QueryPeriod) {
  return setItem(getPeriodStorageKey(domain), value)
}

export const isValidComparison = (
  comparison: unknown
): comparison is ComparisonMode =>
  Object.values<unknown>(ComparisonMode).includes(comparison)

export const getMatchDayOfWeekStorageKey = (domain: string) =>
  getDomainScopedStorageKey('comparison_match_day_of_week', domain)

export const isValidMatchDayOfWeek = (
  matchDayOfWeek: unknown
): matchDayOfWeek is boolean =>
  [true, false].includes(matchDayOfWeek as boolean)

export const storeMatchDayOfWeek = (domain: string, matchDayOfWeek: boolean) =>
  setItem(getMatchDayOfWeekStorageKey(domain), matchDayOfWeek.toString())

export const getStoredMatchDayOfWeek = function (
  domain: string,
  fallbackValue: boolean | null
) {
  const storedValue = getItem(getMatchDayOfWeekStorageKey(domain))
  if (storedValue === 'true') {
    return true
  }
  if (storedValue === 'false') {
    return false
  }
  return fallbackValue
}

export const getComparisonModeStorageKey = (domain: string) =>
  getDomainScopedStorageKey('comparison_mode', domain)

export const getStoredComparisonMode = function (
  domain: string,
  fallbackValue: ComparisonMode | null
): ComparisonMode | null {
  const storedValue = getItem(getComparisonModeStorageKey(domain))
  if (Object.values(ComparisonMode).includes(storedValue)) {
    return storedValue
  }

  return fallbackValue
}

export const storeComparisonMode = function (
  domain: string,
  mode: ComparisonMode
) {
  setItem(getComparisonModeStorageKey(domain), mode)
}

export const isComparisonEnabled = function (
  mode?: ComparisonMode | null
): mode is Exclude<ComparisonMode, ComparisonMode.off> {
  if (
    [
      ComparisonMode.custom,
      ComparisonMode.previous_period,
      ComparisonMode.year_over_year
    ].includes(mode as ComparisonMode)
  ) {
    return true
  }
  return false
}

export const getSearchToToggleComparison = ({
  site,
  query
}: {
  site: PlausibleSite
  query: DashboardQuery
}): Required<AppNavigationTarget>['search'] => {
  return (search) => {
    if (isComparisonEnabled(query.comparison)) {
      return {
        ...search,
        ...clearedComparisonSearch,
        comparison: ComparisonMode.off,
        keybindHint: 'X'
      }
    }
    const storedMode = getStoredComparisonMode(site.domain, null)
    const newMode = isComparisonEnabled(storedMode)
      ? storedMode
      : DEFAULT_COMPARISON_MODE
    return {
      ...search,
      ...clearedComparisonSearch,
      comparison: newMode,
      keybindHint: 'X'
    }
  }
}

export const getSearchToApplyCustomDates = ([selectionStart, selectionEnd]: [
  Date,
  Date
]): AppNavigationTarget['search'] => {
  const [from, to] = [
    parseNaiveDate(selectionStart),
    parseNaiveDate(selectionEnd)
  ]
  const singleDaySelected = from.isSame(to, 'day')

  if (singleDaySelected) {
    return (search) => ({
      ...search,
      ...clearedDateSearch,
      period: QueryPeriod.day,
      date: formatISO(from),
      keybindHint: 'C'
    })
  }

  return (search) => ({
    ...search,
    ...clearedDateSearch,
    period: QueryPeriod.custom,
    from: formatISO(from),
    to: formatISO(to),
    keybindHint: 'C'
  })
}

export const getSearchToApplyCustomComparisonDates = ([
  selectionStart,
  selectionEnd
]: [Date, Date]): AppNavigationTarget['search'] => {
  const [from, to] = [
    parseNaiveDate(selectionStart),
    parseNaiveDate(selectionEnd)
  ]

  return (search) => ({
    ...search,
    comparison: ComparisonMode.custom,
    compare_from: formatISO(from),
    compare_to: formatISO(to),
    keybindHint: null
  })
}

export type LinkItem = [
  string[],
  {
    search: AppNavigationTarget['search']
    isActive: (options: {
      site: PlausibleSite
      query: DashboardQuery
    }) => boolean
    onClick?: () => void
  }
]

export const getDatePeriodGroups = (
  site: PlausibleSite
): Array<Array<LinkItem>> => [
  [
    [
      ['Today', 'D'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.day,
          date: formatISO(nowForSite(site)),
          keybindHint: 'D'
        }),
        isActive: ({ query }) =>
          query.period === QueryPeriod.day &&
          isSameDate(query.date, nowForSite(site))
      }
    ],
    [
      ['Yesterday', 'E'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.day,
          date: formatISO(yesterday(site)),
          keybindHint: 'E'
        }),
        isActive: ({ query }) =>
          query.period === QueryPeriod.day &&
          isSameDate(query.date, yesterday(site))
      }
    ],
    [
      ['Realtime', 'R'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.realtime,
          keybindHint: 'R'
        }),
        isActive: ({ query }) => query.period === QueryPeriod.realtime
      }
    ]
  ],
  [
    [
      ['Last 7 Days', 'W'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod['7d'],
          keybindHint: 'W'
        }),
        isActive: ({ query }) => query.period === QueryPeriod['7d']
      }
    ],
    [
      ['Last 30 Days', 'T'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod['30d'],
          keybindHint: 'T'
        }),
        isActive: ({ query }) => query.period === QueryPeriod['30d']
      }
    ]
  ],
  [
    [
      ['Month to Date', 'M'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.month,
          keybindHint: 'M'
        }),
        isActive: ({ query }) =>
          query.period === QueryPeriod.month &&
          isSameMonth(query.date, nowForSite(site))
      }
    ],
    [
      ['Last Month'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.month,
          date: formatISO(lastMonth(site)),
          keybindHint: null
        }),
        isActive: ({ query }) =>
          query.period === QueryPeriod.month &&
          isSameMonth(query.date, lastMonth(site))
      }
    ]
  ],
  [
    [
      ['Year to Date', 'Y'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.year,
          keybindHint: 'Y'
        }),
        isActive: ({ query }) =>
          query.period === QueryPeriod.year && isThisYear(site, query.date)
      }
    ],
    [
      ['Last 12 Months', 'L'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod['12mo'],
          keybindHint: 'L'
        }),
        isActive: ({ query }) => query.period === QueryPeriod['12mo']
      }
    ]
  ],
  [
    [
      ['All time', 'A'],
      {
        search: (s) => ({
          ...s,
          ...clearedDateSearch,
          period: QueryPeriod.all,
          keybindHint: 'A'
        }),
        isActive: ({ query }) => query.period === QueryPeriod.all
      }
    ]
  ]
]

export const last6MonthsLinkItem: LinkItem = [
  ['Last 6 months', 'S'],
  {
    search: (s) => ({
      ...s,
      ...clearedDateSearch,
      period: QueryPeriod['6mo'],
      keybindHint: 'S'
    }),
    isActive: ({ query }) => query.period === QueryPeriod['6mo']
  }
]

export const getCompareLinkItem = ({
  query,
  site
}: {
  query: DashboardQuery
  site: PlausibleSite
}): LinkItem => [
  [
    isComparisonEnabled(query.comparison) ? 'Disable comparison' : 'Compare',
    'X'
  ],
  {
    search: getSearchToToggleComparison({ site, query }),
    isActive: () => false
  }
]

export function useSaveTimePreferencesToStorage({
  site,
  period,
  comparison,
  match_day_of_week
}: {
  site: PlausibleSite
  period: unknown
  comparison: unknown
  match_day_of_week: unknown
}) {
  useEffect(() => {
    if (
      isValidPeriod(period) &&
      ![QueryPeriod.custom, QueryPeriod.realtime].includes(period)
    ) {
      storePeriod(site.domain, period)
    }
    if (isValidComparison(comparison) && comparison !== ComparisonMode.custom) {
      storeComparisonMode(site.domain, comparison)
    }
    if (isValidMatchDayOfWeek(match_day_of_week)) {
      storeMatchDayOfWeek(site.domain, match_day_of_week)
    }
  }, [period, comparison, match_day_of_week, site.domain])
}

export function getSavedTimePreferencesFromStorage({
  site
}: {
  site: PlausibleSite
}): {
  period: null | QueryPeriod
  comparison: null | ComparisonMode
  match_day_of_week: boolean | null
} {
  const stored = {
    period: getStoredPeriod(site.domain, null),
    comparison: getStoredComparisonMode(site.domain, null),
    match_day_of_week: getStoredMatchDayOfWeek(site.domain, true)
  }
  return stored
}

export function getDashboardTimeSettings({
  searchValues,
  storedValues,
  defaultValues
}: {
  searchValues: Record<'period' | 'comparison' | 'match_day_of_week', unknown>
  storedValues: ReturnType<typeof getSavedTimePreferencesFromStorage>
  defaultValues: Pick<
    DashboardQuery,
    'period' | 'comparison' | 'match_day_of_week'
  >
}): Pick<DashboardQuery, 'period' | 'comparison' | 'match_day_of_week'> {
  let period: QueryPeriod
  if (isValidPeriod(searchValues.period)) {
    period = searchValues.period
  } else {
    period = isValidPeriod(storedValues.period)
      ? storedValues.period
      : defaultValues.period
  }

  let comparison: ComparisonMode | null

  if ([QueryPeriod.realtime, QueryPeriod.all].includes(period)) {
    comparison = null
  } else {
    comparison = isValidComparison(searchValues.comparison)
      ? searchValues.comparison
      : storedValues.comparison

    if (!isComparisonEnabled(comparison)) {
      comparison = null
    }
  }

  const match_day_of_week = isValidMatchDayOfWeek(
    searchValues.match_day_of_week
  )
    ? (searchValues.match_day_of_week as boolean)
    : isValidMatchDayOfWeek(storedValues.match_day_of_week)
      ? (storedValues.match_day_of_week as boolean)
      : defaultValues.match_day_of_week

  return {
    period,
    comparison,
    match_day_of_week
  }
}

export function DisplaySelectedPeriod() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  if (query.period === 'day') {
    if (isToday(site, query.date)) {
      return 'Today'
    }
    return formatDay(query.date)
  }
  if (query.period === '7d') {
    return 'Last 7 days'
  }
  if (query.period === '30d') {
    return 'Last 30 days'
  }
  if (query.period === 'month') {
    if (isThisMonth(site, query.date)) {
      return 'Month to Date'
    }
    return formatMonthYYYY(query.date)
  }
  if (query.period === '6mo') {
    return 'Last 6 months'
  }
  if (query.period === '12mo') {
    return 'Last 12 months'
  }
  if (query.period === 'year') {
    if (isThisYear(site, query.date)) {
      return 'Year to Date'
    }
    return formatYear(query.date)
  }
  if (query.period === 'all') {
    return 'All time'
  }
  if (query.period === 'custom') {
    return formatDateRange(site, query.from, query.to)
  }
  return 'Realtime'
}
