import { numberLongFormatter, numberShortFormatter } from './number-formatter'

type Money = { long: string; short: string }

export function formatMoneyShort(value: Money | number | null) {
  if (typeof value == 'number') {
    return numberShortFormatter(value)
  } else if (value) {
    return value.short
  } else {
    return '-'
  }
}

export function formatMoneyLong(value: Money | number | null) {
  if (typeof value == 'number') {
    return numberLongFormatter(value)
  } else if (value) {
    return value.long
  } else {
    return '-'
  }
}
