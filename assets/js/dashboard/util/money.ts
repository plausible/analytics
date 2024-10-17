type Money = { long: string, short: string }

export function formatMoneyShort(value: Money | null) {
  if (value) {
    return value.short
  } else {
    return "-"
  }
}

export function formatMoneyLong(value: Money | null) {
  if (value) {
    return value.long
  } else {
    return "-"
  }
}
