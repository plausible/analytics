import {formatDay, formatMonthYYYY, nowInOffset, parseUTCDate} from './date'

const PERIODS = ['realtime', 'day', 'month', '7d', '30d', '60d', '6mo', '12mo', 'custom']

export function parseQuery(querystring, site) {
  const q = new URLSearchParams(querystring)
  let period = q.get('period')
  const periodKey = 'period__' + site.domain

  if (PERIODS.includes(period)) {
    if (period !== 'custom') window.localStorage[periodKey] = period
  } else {
    if (window.localStorage[periodKey]) {
      period = window.localStorage[periodKey]
    } else {
      period = '30d'
    }
  }

  return {
    period: period,
    date: q.get('date') ? parseUTCDate(q.get('date')) : nowInOffset(site.offset),
    from: q.get('from') ? parseUTCDate(q.get('from')) : undefined,
    to: q.get('to') ? parseUTCDate(q.get('to')) : undefined,
    filters: {'goal': q.get('goal')}
  }
}

export function toHuman(query) {
  if (query.period === 'day') {
    return `on ${formatDay(query.date)}`
  } else if (query.period === 'month') {
    return `in ${formatMonthYYYY(query.date)}`
  } else if (query.period === '7d') {
    return 'in the last 7 days'
  } else if (query.period === '30d') {
    return 'in the last 30 days'
  } else if (query.period === '60d') {
    return 'in the last 60 days'
  } else if (query.period === '6mo') {
    return 'in the last 6 months'
  } else if (query.period === '12mo') {
    return 'in the last 12 months'
  }
}

export function removeQueryParam(search, parameter) {
  const q = new URLSearchParams(search)
  q.delete(parameter)
  return q.toString()
}

export function eventName(query) {
  if (query.filters.goal) {
    if (query.filters.goal.startsWith('Visit ')) {
      return 'pageviews'
    }
    return 'events'
  } else {
    return 'pageviews'
  }
}
