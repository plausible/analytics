// https://stackoverflow.com/a/50130338
export function formatISO(date) {
  return new Date(date.getTime() - (date.getTimezoneOffset() * 60000))
    .toISOString()
    .split("T")[0];
}

export function shiftMonths(date, months) {
  const newDate = new Date(date.getTime())
  newDate.setMonth(newDate.getMonth() + months)
  return newDate
}

export function shiftDays(date, days) {
  const newDate = new Date(date.getTime())
  newDate.setDate(newDate.getDate() + days)
  return newDate
}

const MONTHS = [
  "January", "February", "March",
  "April", "May", "June", "July",
  "August", "September", "October",
  "November", "December"
]

export function formatMonthYYYY(date) {
  return `${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

export function formatMonth(date) {
  return `${MONTHS[date.getMonth()]}`;
}

export function formatDay(date) {
  return `${date.getDate()} ${formatMonth(date)}`;
}

export function formatDayShort(date) {
  return `${date.getDate()} ${formatMonth(date).substring(0, 3)}`;
}

export function formatFullDate(date) {
  const shortDate = formatMonth(date).substring(0, 3)
  return `${shortDate} ${date.getDate()}, ${date.getFullYear()}`;
}

export function parseUTCDate(dateString) {
  var date = new Date(dateString);
  return new Date(date.getTime() + date.getTimezoneOffset() * 60000);
}

// https://stackoverflow.com/a/11124448
export function nowInOffset(siteOffset) {
  const browserOffset = (new Date()).getTimezoneOffset() * 60
  return new Date(new Date().getTime() + (siteOffset * 1000) + (browserOffset * 1000))
}

export function isToday(site, date) {
  return formatISO(date) === formatISO(nowInOffset(site.offset))
}
