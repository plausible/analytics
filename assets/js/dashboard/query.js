import {formatDay, formatMonthYYYY, newDateInOffset} from './date'

const PERIODS = ['day', 'month', '7d', '30d', '3mo', '6mo']

export function parseQuery(querystring, site) {
  const q = new URLSearchParams(querystring)
  let period = q.get('period')
  const periodKey = 'period__' + site.domain

  if (PERIODS.includes(period)) {
    window.localStorage[periodKey] = period
  } else {
    if (window.localStorage[periodKey]) {
      period = window.localStorage[periodKey]
    } else {
      period = '30d'
    }
  }

  return {
    period: period,
    date: q.get('date') ? new Date(q.get('date')) : newDateInOffset(site.offset),
    filters: {
      'goal': q.get('goal')
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
  } else if (query.period === '3mo') {
    return 'in the last 3 months'
  } else if (query.period === '6mo') {
    return 'in the last 6 months'
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
