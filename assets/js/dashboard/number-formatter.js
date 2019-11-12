const THOUSAND = 1000
const HUNDRED_THOUSAND = 100000
const MILLION = 1000000
const HUNDRED_MILLION = 100000000

export default function numberFormatter(num) {
  if (num >= THOUSAND && num < MILLION) {
    const thousands = num / THOUSAND
    if (thousands === Math.floor(thousands) || num >= HUNDRED_THOUSAND) {
      return Math.floor(thousands) + 'k'
    } else {
      return (Math.floor(thousands * 10) / 10) + 'k'
    }
  } else if (num >= MILLION && num < HUNDRED_MILLION) {
    const millions = num / MILLION
    if (millions === Math.floor(millions)) {
      return Math.floor(millions) + 'm'
    } else {
      return (Math.floor(millions * 10) / 10) + 'm'
    }
  } else {
    return num
  }
}
