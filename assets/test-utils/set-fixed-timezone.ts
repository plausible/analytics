/**
 * @format
 */

/**
 * @returns sets a fixed timezone for the test process,
 * otherwise test runs on different servers and machines may be inconsistent
 */
function setFixedTimezone() {
  process.env.TZ = 'UTC'
}

setFixedTimezone()
