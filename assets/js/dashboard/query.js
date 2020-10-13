import {formatDay, formatMonthYYYY, nowForSite, parseUTCDate} from './date'

const PERIODS = ['realtime', 'day', 'month', '7d', '30d', '6mo', '12mo', 'custom']

export function parseQuery(querystring, site) {
  const q = new URLSearchParams(querystring)
  let period = q.get('period')
  const periodKey = 'period__' + site.domain

  if (PERIODS.includes(period)) {
    if (period !== 'custom' && period !== 'realtime') window.localStorage[periodKey] = period
  } else {
    if (window.localStorage[periodKey]) {
      period = window.localStorage[periodKey]
    } else {
      period = '30d'
    }
  }

  return {
    period: period,
    date: q.get('date') ? parseUTCDate(q.get('date')) : nowForSite(site),
    from: q.get('from') ? parseUTCDate(q.get('from')) : undefined,
    to: q.get('to') ? parseUTCDate(q.get('to')) : undefined,
    filters: {
      'goal': q.get('goal'),
      'source': q.get('source'),
      'utm_medium': q.get('utm_medium'),
      'utm_source': q.get('utm_source'),
      'utm_campaign': q.get('utm_campaign'),
      'referrer': q.get('referrer'),
      'screen': q.get('screen'),
      'browser': q.get('browser'),
      'os': q.get('os'),
      'country': q.get('country'),
      'page': q.get('page')
    }
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
