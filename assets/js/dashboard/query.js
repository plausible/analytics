import {formatDay, formatMonthYYYY, newDateInOffset} from './date'

function parseQueryString(queryString) {
    var query = {};
    var pairs = (queryString[0] === '?' ? queryString.substr(1) : queryString).split('&');
    for (var i = 0; i < pairs.length; i++) {
        var pair = pairs[i].split('=');
        query[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
    }
    return query;
}

const PERIODS = ['day', 'month', '7d', '30d', '3mo', '6mo']

export function parseQuery(querystring, site) {
  let {period, date} = parseQueryString(querystring)
  const periodKey = 'period__' + site.domain

  if (PERIODS.includes(period)) {
    window.localStorage[periodKey] = period
  } else {
    if (window.localStorage[periodKey]) {
      period = window.localStorage[periodKey]
    } else {
      period = '6mo'
    }
  }

  return {
    period: period,
    date: date ? new Date(date) : newDateInOffset(site.offset)
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
