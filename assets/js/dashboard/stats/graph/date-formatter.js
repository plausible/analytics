import { parseUTCDate, formatMonthYYYY, formatDay, formatDayShort } from '../../util/date'

const browserDateFormat = Intl.DateTimeFormat(navigator.language, { hour: 'numeric' })

const is12HourClock = function () {
  return browserDateFormat.resolvedOptions().hour12
}

const parseISODate = function (isoDate) {
  const date = parseUTCDate(isoDate)
  const minutes = date.getMinutes();
  const year = date.getFullYear()
  return { date, minutes, year }
}

const getYearString = (options, year) => options.shouldShowYear ? ` ${year}` : ''

const formatHours = function (isoDate) {
  const monthIndex = 1
  const dateParts = isoDate.split(/[^0-9]/);
  dateParts[monthIndex] = dateParts[monthIndex] - 1

  const localDate = new Date(...dateParts)
  return browserDateFormat.format(localDate)
}

const monthIntervalFormatter = {
  long(isoDate, options) {
    const formatted = this.short(isoDate, options)
    return options.isBucketPartial ? `Partial of ${formatted}` : formatted
  },
  short(isoDate, _options) {
    const { date } = parseISODate(isoDate)
    return formatMonthYYYY(date)
  }
}

const weekIntervalFormatter = {
  long(isoDate, options) {
    const formatted = this.short(isoDate, options)
    return options.isBucketPartial ? `Partial week of ${formatted}` : `Week of ${formatted}`
  },
  short(isoDate, options) {
    const { date, year } = parseISODate(isoDate)
    return `${formatDayShort(date)}${getYearString(options, year)}`
  }
}

const dateIntervalFormatter = {
  long(isoDate, _options) {
    const { date } = parseISODate(isoDate)
    return formatDay(date)
  },
  short(isoDate, options) {
    const { date, year } = parseISODate(isoDate)
    return `${formatDayShort(date)}${getYearString(options, year)}`
  }
}

const hourIntervalFormatter = {
  long(isoDate, options) {
    return this.short(isoDate, options)
  },
  short(isoDate, _options) {
    const formatted = formatHours(isoDate)

    if (is12HourClock()) {
      return formatted.replace(' ', '').toLowerCase()
    } else {
      return formatted.replace(/[^0-9]/g, '').concat(":00")
    }
  }
}

const minuteIntervalFormatter = {
  long(isoDate, options) {
    if (options.period == 'realtime') {
      const minutesAgo = Math.abs(isoDate)
      return minutesAgo === 1 ? '1 minute ago' : minutesAgo + ' minutes ago'
    } else {
      return this.short(isoDate, options)
    }
  },
  short(isoDate, options) {
    if (options.period === 'realtime') return isoDate + 'm'

    const { minutes } = parseISODate(isoDate)
    const formatted = formatHours(isoDate)
    if (is12HourClock()) {
      return formatted.replace(' ', ':' + (minutes < 10 ? `0${minutes}` : minutes)).toLowerCase()
    } else {
      return formatted.replace(/[^0-9]/g, '').concat(":" + (minutes < 10 ? `0${minutes}` : minutes))
    }
  }
}

// Each interval has a different date and time format. This object maps each
// interval with two functions: `long` and `short`, that formats date and time
// accordingly.
const factory = {
  month: monthIntervalFormatter,
  week: weekIntervalFormatter,
  date: dateIntervalFormatter,
  hour: hourIntervalFormatter,
  minute: minuteIntervalFormatter
}

/**
 * Returns a function that formats a ISO 8601 timestamp based on the given
 * arguments.
 *
 * The preferred date and time format in the dashboard depends on the selected
 * interval and period. For example, in real-time view only the time is necessary,
 * while other intervals require dates to be displayed.
 * @param {Object} config - Configuration object for determining formatter.
 *
 * @param {string} config.interval - The interval of the query, e.g. `minute`, `hour`
 * @param {boolean} config.longForm - Whether the formatted result should be in long or
 * short form.
 * @param {string} config.period - The period of the query, e.g. `12mo`, `day`
 * @param {boolean} config.isPeriodFull - Indicates whether the interval has been cut
 * off by the requested date range or not. If false, the returned formatted date
 * indicates this cut off, e.g. `Partial week of November 8`.
 * @param {boolean} config.shouldShowYear - Should the year be appended to the date?
 * Defaults to false. Rendering year string is a newer opt-in feature to be enabled where needed.
 */
export default function dateFormatter({ interval, longForm, period, isPeriodFull, shouldShowYear = false }) {
  const displayMode = longForm ? 'long' : 'short'
  const options = { period: period, interval: interval, isBucketPartial: !isPeriodFull, shouldShowYear }
  return function (isoDate, _index, _ticks) {
    return factory[interval][displayMode](isoDate, options)
  }
}
