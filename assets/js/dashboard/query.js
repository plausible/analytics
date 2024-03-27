import React from 'react'
import { Link, withRouter } from 'react-router-dom'
import { nowForSite } from './util/date'
import * as storage from './util/storage'
import { COMPARISON_DISABLED_PERIODS, getStoredComparisonMode, isComparisonEnabled, getStoredMatchDayOfWeek } from './comparison-input'

import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';

dayjs.extend(utc)

const PERIODS = ['realtime', 'day', 'month', '7d', '30d', '6mo', '12mo', 'year', 'all', 'custom']

export function parseQuery(querystring, site) {
  const q = new URLSearchParams(querystring)
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
    experimental_session_count: q.get('experimental_session_count'),
    filters: {
      'goal': q.get('goal'),
      'props': JSON.parse(q.get('props')),
      'source': q.get('source'),
      'utm_medium': q.get('utm_medium'),
      'utm_source': q.get('utm_source'),
      'utm_campaign': q.get('utm_campaign'),
      'utm_content': q.get('utm_content'),
      'utm_term': q.get('utm_term'),
      'referrer': q.get('referrer'),
      'screen': q.get('screen'),
      'browser': q.get('browser'),
      'browser_version': q.get('browser_version'),
      'os': q.get('os'),
      'os_version': q.get('os_version'),
      'country': q.get('country'),
      'region': q.get('region'),
      'city': q.get('city'),
      'page': q.get('page'),
      'hostname': q.get('hostname'),
      'entry_page': q.get('entry_page'),
      'exit_page': q.get('exit_page')
    }
  }
}

export function appliedFilters(query) {
  const propKeys = Object.entries(query.filters.props || {})
    .map(([key, value]) => ({ key, value, filterType: 'props' }))

  return Object.entries(query.filters)
    .map(([key, value]) => ({ key, value, filterType: key }))
    .filter(({ key, value }) => key !== 'props' && !!value)
    .concat(propKeys)
}

function generateQueryString(data) {
  const query = new URLSearchParams(window.location.search)
  Object.keys(data).forEach(key => {
    if (!data[key]) {
      query.delete(key)
      return
    }

    query.set(key, data[key])
  })
  return query.toString()
}

export function navigateToQuery(history, queryFrom, newData) {
  // if we update any data that we store in localstorage, make sure going back in history will
  // revert them
  if (newData.period && newData.period !== queryFrom.period) {
    const replaceQuery = new URLSearchParams(window.location.search)
    replaceQuery.set('period', queryFrom.period)
    history.replace({ search: replaceQuery.toString() })
  }

  // then push the new query to the history
  history.push({ search: generateQueryString(newData) })
}

class QueryLink extends React.Component {
  constructor(props) {
    super(props)
    this.onClick = this.onClick.bind(this)
  }

  onClick(e) {
    e.preventDefault()
    navigateToQuery(this.props.history, this.props.query, this.props.to)
    if (this.props.onClick) this.props.onClick(e)
  }

  render() {
    const { to, ...props } = this.props
    return (
      <Link
        {...props}
        to={{ pathname: window.location.pathname, search: generateQueryString(to) }}
        onClick={this.onClick}
      />
    )
  }
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
        history.push({ pathname: window.location.pathname, search: generateQueryString(to) })
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

export function eventName(query) {
  if (query.filters.goal) {
    if (query.filters.goal.startsWith('Visit ')) {
      return 'pageviews'
    }
    return 'events'
  }
  return 'pageviews'
}
