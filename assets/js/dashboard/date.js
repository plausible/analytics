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

export function formatMonth(date) {
  return `${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

export function formatDay(date) {
  return `${date.getDate()} ${formatMonth(date)}`;
}
