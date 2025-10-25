import { runThrottledCheck } from './run-check'

export async function waitForPlausibleFunction(timeout = 5000) {
  const checkFn = (opts) => {
    if (window.plausible?.l) {
      return true
    }
    if (opts.timeout) {
      return false
    }
    return 'continue'
  }
  return await runThrottledCheck(checkFn, { timeout: timeout, interval: 100 })
}
