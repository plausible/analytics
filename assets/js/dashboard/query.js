function parseQueryString(queryString) {
    var query = {};
    var pairs = (queryString[0] === '?' ? queryString.substr(1) : queryString).split('&');
    for (var i = 0; i < pairs.length; i++) {
        var pair = pairs[i].split('=');
        query[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
    }
    return query;
}

const PERIODS = ['day', 'month', '7d', '3mo', '6mo']

export function parseQuery(querystring, siteDomain) {
  let {period, date} = parseQueryString(querystring)
  const periodKey = 'period__' + siteDomain

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
    date: date ? new Date(date) : new Date()
  }
}
