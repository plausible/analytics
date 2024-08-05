import React, {useCallback} from 'react'
import { parseSearch, stringifySearch } from './util/url'
import { AppNavigationLink, useAppNavigate } from './navigation/use-app-navigate'
import { nowForSite } from './util/date'
import * as storage from './util/storage'
import { COMPARISON_DISABLED_PERIODS, getStoredComparisonMode, isComparisonEnabled, getStoredMatchDayOfWeek } from './comparison-input'
import { getFiltersByKeyPrefix, parseLegacyFilter, parseLegacyPropsFilter } from './util/filters'

import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import { useQueryContext } from './query-context'

dayjs.extend(utc)

const PERIODS = ['realtime', 'day', 'month', '7d', '30d', '6mo', '12mo', 'year', 'all', 'custom']

export function parseQuery(searchRecord, site) {
  const getValue = (k) => searchRecord[k];
  let period = getValue('period')
  const periodKey = `period__${site.domain}`

  if (PERIODS.includes(period)) {
    if (period !== 'custom' && period !== 'realtime') {storage.setItem(periodKey, period)}
  } else if (storage.getItem(periodKey)) {
    period = storage.getItem(periodKey)
  } else {
    period = '30d'
  }

  let comparison = getValue('comparison') ?? getStoredComparisonMode(site.domain, null)
  if (COMPARISON_DISABLED_PERIODS.includes(period) || !isComparisonEnabled(comparison)) comparison = null

  let matchDayOfWeek = getValue('match_day_of_week') ?? getStoredMatchDayOfWeek(site.domain, true)

  return {
    period,
    comparison,
    compare_from: getValue('compare_from') ? dayjs.utc(getValue('compare_from')) : undefined,
    compare_to: getValue('compare_to') ? dayjs.utc(getValue('compare_to')) : undefined,
    date: getValue('date') ? dayjs.utc(getValue('date')) : nowForSite(site),
    from: getValue('from') ? dayjs.utc(getValue('from')) : undefined,
    to: getValue('to') ? dayjs.utc(getValue('to')) : undefined,
    match_day_of_week: matchDayOfWeek === true,
    with_imported: getValue('with_imported') ?? true,
    filters: getValue('filters') || [],
    labels: getValue('labels') || {}
  }
}

export function addFilter(query, filter) {
  return { ...query, filters: [...query.filters, filter] }
}



export function navigateToQuery(navigate, {period}, newPartialSearchRecord) {
  // if we update any data that we store in localstorage, make sure going back in history will
  // revert them
  if (newPartialSearchRecord.period && newPartialSearchRecord.period !== period) {
    navigate({ search: (search) => ({ ...search, period: period }), replace: true })
  }

  // then push the new query to the history
  navigate({ search: (search) => ({ ...search, ...newPartialSearchRecord }) })
}

const LEGACY_URL_PARAMETERS = {
  'goal': null,
  'source': null,
  'utm_medium': null,
  'utm_source': null,
  'utm_campaign': null,
  'utm_content': null,
  'utm_term': null,
  'referrer': null,
  'screen': null,
  'browser': null,
  'browser_version': null,
  'os': null,
  'os_version': null,
  'country': 'country_labels',
  'region': 'region_labels',
  'city': 'city_labels',
  'page': null,
  'hostname': null,
  'entry_page': null,
  'exit_page': null,
}

// Called once when dashboard is loaded load. Checks whether old filter style is used and if so,
// updates the filters and updates location
export function filtersBackwardsCompatibilityRedirect(windowLocation, windowHistory) {
  const searchRecord = parseSearch(windowLocation.search)
  const getValue = (k) => searchRecord[k];
  
  // New filters are used - no need to do anything
  if (getValue("filters")) {
    return
  }
  
  const changedSearchRecordEntries = [];
  let filters = []
  let labels = {}

  for (const [key, value] of Object.entries(searchRecord)) {
    if (LEGACY_URL_PARAMETERS.hasOwnProperty(key)) {
      const filter = parseLegacyFilter(key, value)
      filters.push(filter)
      const labelsKey = LEGACY_URL_PARAMETERS[key]
      if (labelsKey && getValue(labelsKey)) {
        const clauses = filter[2]
        const labelsValues = getValue(labelsKey).split('|').filter(label => !!label)
        const newLabels = Object.fromEntries(clauses.map((clause, index) => [clause, labelsValues[index]]))

        labels = Object.assign(labels, newLabels)
      }
    } else {
      changedSearchRecordEntries.push([key, value])
    }
  }

  if (getValue('props')) {
    filters.push(...parseLegacyPropsFilter(getValue('props')))
  }

  if (filters.length > 0) {
    changedSearchRecordEntries.push(['filters', filters], ['labels', labels])
    windowHistory.pushState({}, null, `${windowLocation.pathname}${stringifySearch(Object.fromEntries(changedSearchRecordEntries))}`)
  }
}

// Returns a boolean indicating whether the given query includes a
// non-empty goal filterset containing a single, or multiple revenue
// goals with the same currency. Used to decide whether to render
// revenue metrics in a dashboard report or not.
export function revenueAvailable(query, site) {
  const revenueGoalsInFilter = site.revenueGoals.filter((rg) => {
    const goalFilters = getFiltersByKeyPrefix(query, "goal")

    return goalFilters.some(([_op, _key, clauses]) => {
      return clauses.includes(rg.event_name)
    })
  })

  const singleCurrency = revenueGoalsInFilter.every((rg) => {
    return rg.currency === revenueGoalsInFilter[0].currency
  })

  return revenueGoalsInFilter.length > 0 && singleCurrency
}

export function QueryLink({ to, search, className, children, onClick }) {
  const navigate = useAppNavigate();
  const { query } = useQueryContext();

  const handleClick = useCallback((e) => {
    e.preventDefault()
    navigateToQuery(navigate, query, search)
    if (onClick) {
      onClick(e)
    }
  }, [navigate, onClick, query, search])

  return (
    <AppNavigationLink
      to={to}
      search={(currentSearch) => ({...currentSearch, ...search})}
      className={className}
      onClick={handleClick}
    >
      {children}
    </AppNavigationLink>
  )
}

export function QueryButton({ search, disabled, className, children, onClick }) {
  const navigate = useAppNavigate();
  const { query } = useQueryContext();

  const handleClick = useCallback((e) => {
    e.preventDefault()
    navigateToQuery(navigate, query, search)
    if (onClick) {
      onClick(e)
    }
  }, [navigate, onClick, query, search])

  return (
    <button
      className={className}
      onClick={handleClick}
      type="button"
      disabled={disabled}
    >
      {children}
    </button>
  )
}

