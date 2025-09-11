import { runThrottledCheck } from './run-check'

export async function plausibleFunctionCheck(log) {
  log('Checking for Plausible function...')
  const plausibleFound = await waitForPlausibleFunction()

  if (plausibleFound) {
    log('Plausible function found. Executing test event...')
    const callbackResult = await testPlausibleCallback(log)
    log(`Test event callback response: ${callbackResult.status}`)
    return { plausibleInstalled: true, callbackStatus: callbackResult.status }
  } else {
    log('Plausible function not found')
    return { plausibleInstalled: false }
  }
}

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

function testPlausibleCallback(log) {
  return new Promise((resolve) => {
    let callbackResolved = false

    const callbackTimeout = setTimeout(() => {
      if (!callbackResolved) {
        callbackResolved = true
        log('Timeout waiting for Plausible function callback')
        resolve({ status: undefined })
      }
    }, 5000)

    try {
      window.plausible('verification-agent-test', {
        callback: function (options) {
          if (!callbackResolved) {
            callbackResolved = true
            clearTimeout(callbackTimeout)
            resolve({ status: options && options.status ? options.status : -1 })
          }
        }
      })
    } catch (error) {
      if (!callbackResolved) {
        callbackResolved = true
        clearTimeout(callbackTimeout)
        log('Error calling plausible function:', error)
        resolve({ status: -1 })
      }
    }
  })
}
