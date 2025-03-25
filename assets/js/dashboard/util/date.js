import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'

dayjs.extend(utc)

// https://stackoverflow.com/a/50130338
export function formatISO(date) {
  return date.format('YYYY-MM-DD')
}

export function shiftMonths(date, months) {
  return date.add(months, 'months')
}

export function shiftDays(date, days) {
  return date.add(days, 'days')
}

export function formatMonthYYYY(date) {
  return date.format('MMMM YYYY')
}

export function formatYear(date) {
  return `Year of ${date.year()}`
}

export function formatYearShort(date) {
  return date.getUTCFullYear().toString().substring(2)
}

export function formatDay(date) {
  if (date.year() !== dayjs().year()) {
    return date.format('ddd, DD MMM YYYY')
  } else {
    return date.format('ddd, DD MMM')
  }
}

export function formatDayShort(date, includeYear = false) {
  if (includeYear) {
    return date.format('D MMM YY')
  } else {
    return date.format('D MMM')
  }
}

export function formatDateRange(site, from, to) {
  if (!from || !to) return
  if (typeof from === 'string') from = parseUTCDate(from)
  if (typeof to === 'string') to = parseUTCDate(to)

  if (from.isSame(to)) {
    return formatDay(from)
  } else if (from.isSame(to, 'year')) {
    const includeYear = !isThisYear(site, from)
    return `${formatDayShort(from, false)} - ${formatDayShort(to, includeYear)}`
  } else {
    return `${formatDayShort(from, true)} - ${formatDayShort(to, true)}`
  }
}

export function parseUTCDate(dateString) {
  return dayjs.utc(dateString)
}

export function parseNaiveDate(dateString) {
  return dayjs(dateString)
}

export function dateForSite(utcDateString, site) {
  return dayjs.utc(utcDateString).utcOffset(site.offset / 60)
}

export function nowForSite(site) {
  return dayjs.utc().utcOffset(site.offset / 60)
}

export function yesterday(site) {
  return shiftDays(nowForSite(site), -1)
}

export function lastMonth(site) {
  return shiftMonths(nowForSite(site), -1)
}

export function isSameDate(date1, date2) {
  return formatISO(date1) === formatISO(date2)
}

export function isSameMonth(date1, date2) {
  return formatMonthYYYY(date1) === formatMonthYYYY(date2)
}

export function isToday(site, date) {
  return isSameDate(date, nowForSite(site))
}

export function isThisMonth(site, date) {
  return formatMonthYYYY(date) === formatMonthYYYY(nowForSite(site))
}

export function isThisYear(site, date) {
  return date.year() === nowForSite(site).year()
}

export function isBefore(date1, date2, period) {
  /* assumes 'day' and 'month' are the only valid periods */
  if (date1.year() !== date2.year()) {
    return date1.year() < date2.year()
  }
  if (period === 'year') {
    return false
  }
  if (date1.month() !== date2.month()) {
    return date1.month() < date2.month()
  }
  if (period === 'month') {
    return false
  }
  return date1.date() < date2.date()
}

export function isAfter(date1, date2, period) {
  /* assumes 'day' and 'month' are the only valid periods */
  if (date1.year() !== date2.year()) {
    return date1.year() > date2.year()
  }
  if (period === 'year') {
    return false
  }
  if (date1.month() !== date2.month()) {
    return date1.month() > date2.month()
  }
  if (period === 'month') {
    return false
  }
  return date1.date() > date2.date()
}
