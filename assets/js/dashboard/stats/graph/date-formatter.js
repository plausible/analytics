import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';

dayjs.extend(utc)

const browserDateFormat = Intl.DateTimeFormat(navigator.language, { hour: 'numeric' })

const is12HourClock = function () {
  return browserDateFormat.resolvedOptions().hour12
}

const monthIntervalFormatter = {
  long(isoDate, options) {
    const formatted = this.short(isoDate, options)
    return options.isBucketPartial ? `Partial of ${formatted}` : formatted
  },
  short(isoDate, _options) {
    return dayjs.utc(isoDate).format('MMMM YYYY')
  }
}

const weekIntervalFormatter = {
  long(isoDate, options) {
    const formatted = this.short(isoDate, options)
    return options.isBucketPartial ? `Partial week of ${formatted}` : `Week of ${formatted}`
  },
  short(isoDate, options) {
    if (options.shouldShowYear) {
      return dayjs.utc(isoDate).format('D MMM YYYY')
    } else {
      return dayjs.utc(isoDate).format('D MMM')
    }
  }
}

const dateIntervalFormatter = {
  long(isoDate, _options) {
    return dayjs.utc(isoDate).format('ddd, D MMM')
  },
  short(isoDate, options) {
    if (options.shouldShowYear) {
      return dayjs.utc(isoDate).format('DD MMM YYYY')
    } else {
      return dayjs.utc(isoDate).format('DD MMM')
    }
  }
}

const hourIntervalFormatter = {
  long(isoDate, options) {
    return this.short(isoDate, options)
  },
  short(isoDate, _options) {
    if (is12HourClock()) {
      return dayjs.utc(isoDate).format('ha')
    } else {
      return dayjs.utc(isoDate).format('HH:mm')
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

    if (is12HourClock()) {
      return dayjs.utc(isoDate).format('h:mma')
    } else {
      return dayjs.utc(isoDate).format('HH:mm')
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
