import React from 'react'
import { Link, withRouter } from 'react-router-dom'
import JsonURL from '@jsonurl/jsonurl'
import { PlausibleSearchParams, updatedQuery } from './util/url'
import { nowForSite } from './util/date'
import * as storage from './util/storage'
import { COMPARISON_DISABLED_PERIODS, getStoredComparisonMode, isComparisonEnabled, getStoredMatchDayOfWeek } from './comparison-input'

import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import { parseLegacyFilter, parseLegacyPropsFilter } from './util/filters'

dayjs.extend(utc)

const PERIODS = ['realtime', 'day', 'month', '7d', '30d', '6mo', '12mo', 'year', 'all', 'custom']

export function parseQuery(querystring, site) {
  const q = new PlausibleSearchParams(querystring)
  let period = q.get('period')
  const periodKey = `period__${site.domain}`

  if (PERIODS.includes(period)) {
    if (period !== 'custom' && period !== 'realtime') storage.setItem(periodKey, period)
  } else if (storage.getItem(periodKey)) {
    period = storage.getItem(periodKey)
  } else {
    period = '30d'
  }

  let comparison = q.get('comparison') || getStoredComparisonMode(site.domain)
  if (COMPARISON_DISABLED_PERIODS.includes(period) || !isComparisonEnabled(comparison)) comparison = null

  let matchDayOfWeek = q.get('match_day_of_week') || getStoredMatchDayOfWeek(site.domain)

  return {
    period,
    comparison,
    compare_from: q.get('compare_from') ? dayjs.utc(q.get('compare_from')) : undefined,
    compare_to: q.get('compare_to') ? dayjs.utc(q.get('compare_to')) : undefined,
    date: q.get('date') ? dayjs.utc(q.get('date')) : nowForSite(site),
    from: q.get('from') ? dayjs.utc(q.get('from')) : undefined,
    to: q.get('to') ? dayjs.utc(q.get('to')) : undefined,
    match_day_of_week: matchDayOfWeek == 'true',
    with_imported: q.get('with_imported') ? q.get('with_imported') === 'true' : true,
    filters: parseJsonUrl(q.get('filters'), []),
    labels: parseJsonUrl(q.get('labels'), {})
  }
}

export function navigateToQuery(history, queryFrom, newData) {
  // if we update any data that we store in localstorage, make sure going back in history will
  // revert them
  if (newData.period && newData.period !== queryFrom.period) {
    history.replace({ search: updatedQuery({ period: queryFrom.period}) })
  }

  // then push the new query to the history
  history.push({ search: updatedQuery(newData) })
}

function parseJsonUrl(value, defaultValue) {
  if (!value) {
    return defaultValue
  }
  return JsonURL.parse(value.replaceAll("=", "%3D"))
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
export function filtersBackwardsCompatibilityRedirect() {
  const q = new PlausibleSearchParams(window.location.search)
  const entries = Array.from(q.entries())

  // New filters are used - no need to do anything
  if (q.get("filters")) {
    return
  }

  let filters = []
  let labels = {}

  for (const [key, value] of entries) {
    if (LEGACY_URL_PARAMETERS.hasOwnProperty(key)) {
      const filter = parseLegacyFilter(key, value)
      filters.push(filter)
      q.delete(key)

      const labelsKey = LEGACY_URL_PARAMETERS[key]
      if (labelsKey && q.get(labelsKey)) {
        const clauses = filter[2]
        const labelsValues = q.get(labelsKey).split('|').filter(label => !!label)
        const newLabels = Object.fromEntries(clauses.map((clause, index) => [clause, labelsValues[index]]))

        labels = Object.assign(labels, newLabels)
        q.delete(labelsKey)
      }
    }
  }

  if (q.get('props')) {
    filters.push(...parseLegacyPropsFilter(q.get('props')))
    q.delete('props')
  }

  if (filters.length > 0) {
    q.set('filters', filters)
    q.set('labels', labels)

    history.pushState({}, null, `${window.location.pathname}?${q.toString()}`)
  }
}

function QueryLink(props) {
  const {query, history, to, className, children} = props

  function onClick(e) {
    e.preventDefault()
    navigateToQuery(history, query, to)
    if (props.onClick) {
      props.onClick(e)
    }
  }

  return (
    <Link
      to={{ pathname: window.location.pathname, search: updatedQuery(to) }}
      className={className}
      onClick={onClick}
    >
      {children}
    </Link>
  )
}

const QueryLinkWithRouter = withRouter(QueryLink)
export { QueryLinkWithRouter as QueryLink };

function QueryButton({ history, query, to, disabled, className, children, onClick }) {
  return (
    <button
      className={className}
      onClick={(event) => {
        event.preventDefault()
        navigateToQuery(history, query, to)
        if (onClick) onClick(event)
        history.push({ pathname: window.location.pathname, search: updatedQuery(to) })
      }}
      type="button"
      disabled={disabled}
    >
      {children}
    </button>
  )
}

const QueryButtonWithRouter = withRouter(QueryButton)
export { QueryButtonWithRouter as QueryButton };
