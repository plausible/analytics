import React from 'react'
import { Link, withRouter } from 'react-router-dom'
import JsonURL from '@jsonurl/jsonurl'
import { PlausibleSearchParams, updatedQuery } from './util/url'
import { nowForSite } from './util/date'
import * as storage from './util/storage'
import { COMPARISON_DISABLED_PERIODS, getStoredComparisonMode, isComparisonEnabled, getStoredMatchDayOfWeek } from './comparison-input'

import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';

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
    experimental_session_count: q.get('experimental_session_count'),
    // :TODO: Backwards compatibility
    filters: JsonURL.parse(q.get('filters')) || [],
    labels: JsonURL.parse(q.get('labels')) || {}
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
        to={{ pathname: window.location.pathname, search: updatedQuery(to) }}
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
