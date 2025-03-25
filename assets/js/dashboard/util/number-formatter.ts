const THOUSAND = 1000
const HUNDRED_THOUSAND = 100000
const MILLION = 1000000
const HUNDRED_MILLION = 100000000
const BILLION = 1000000000
const HUNDRED_BILLION = 100000000000
const TRILLION = 1000000000000

const numberFormat = Intl.NumberFormat('en-US')

export function numberShortFormatter(num: number): string {
  if (num >= THOUSAND && num < MILLION) {
    const thousands = num / THOUSAND
    if (thousands === Math.floor(thousands) || num >= HUNDRED_THOUSAND) {
      return Math.floor(thousands) + 'k'
    } else {
      return Math.floor(thousands * 10) / 10 + 'k'
    }
  } else if (num >= MILLION && num < BILLION) {
    const millions = num / MILLION
    if (millions === Math.floor(millions) || num >= HUNDRED_MILLION) {
      return Math.floor(millions) + 'M'
    } else {
      return Math.floor(millions * 10) / 10 + 'M'
    }
  } else if (num >= BILLION && num < TRILLION) {
    const billions = num / BILLION
    if (billions === Math.floor(billions) || num >= HUNDRED_BILLION) {
      return Math.floor(billions) + 'B'
    } else {
      return Math.floor(billions * 10) / 10 + 'B'
    }
  } else {
    return num.toString()
  }
}

export function numberLongFormatter(num: number): string {
  return numberFormat.format(num)
}

export function nullable<T>(
  formatter: (num: T) => string
): (num: T | null) => string {
  return (num: T | null): string => {
    if (num === null) {
      return '-'
    }
    return formatter(num)
  }
}

function pad(num: number, size: number): string {
  return ('000' + num).slice(size * -1)
}

export function durationFormatter(duration: number): string {
  const hours = Math.floor(duration / 60 / 60)
  const minutes = Math.floor(duration / 60) % 60
  const seconds = Math.floor(duration - minutes * 60 - hours * 60 * 60)
  if (hours > 0) {
    return `${hours}h ${minutes}m ${seconds}s`
  } else if (minutes > 0) {
    return `${minutes}m ${pad(seconds, 2)}s`
  } else {
    return `${seconds}s`
  }
}

export function percentageFormatter(number: number | null): string {
  if (typeof number === 'number') {
    return number + '%'
  } else {
    return '-'
  }
}
