/** @typedef {import('../test/support/types').VerifyV2Args} VerifyV2Args */
/** @typedef {import('../test/support/types').VerifyV2Result} VerifyV2Result */
import { initializeCookieConsentEngine } from './autoconsent-to-cookies'
import { checkDisallowedByCSP } from './check-disallowed-by-csp'

/**
 * Function that verifies if Plausible is installed correctly.
 * @param {VerifyV2Args}
 * @returns {Promise<VerifyV2Result>}
 */

async function verifyPlausibleInstallation({
  timeoutMs,
  responseHeaders,
  debug,
  cspHostToCheck
}) {
  function log(message) {
    if (debug) console.log('[VERIFICATION v2]', message)
  }

  const disallowedByCsp = checkDisallowedByCSP(responseHeaders, cspHostToCheck)

  const { stopRecording, getInterceptedFetch } = startRecordingEventFetchCalls()

  const {
    plausibleIsInitialized,
    plausibleIsOnWindow,
    plausibleVersion,
    plausibleVariant,
    testEvent,
    cookiesConsentResult,
    error: testPlausibleFunctionError
  } = await testPlausibleFunction({
    timeoutMs,
    debug
  })

  if (testPlausibleFunctionError) {
    log(
      `There was an error testing plausible function: ${testPlausibleFunctionError}`
    )
  }

  stopRecording()

  const interceptedTestEvent = getInterceptedFetch('verification-agent-test')

  if (!interceptedTestEvent) {
    log(`No test event request was among intercepted requests`)
  }

  const diagnostics = {
    disallowedByCsp,
    plausibleIsOnWindow,
    plausibleIsInitialized,
    plausibleVersion,
    plausibleVariant,
    testEvent: {
      ...testEvent,
      requestUrl: interceptedTestEvent?.request?.url,
      normalizedBody: interceptedTestEvent?.request?.normalizedBody,
      responseStatus: interceptedTestEvent?.response?.status,
      error: interceptedTestEvent?.error
    },
    cookiesConsentResult
  }

  log({
    diagnostics
  })

  return {
    data: {
      completed: true,
      ...diagnostics
    }
  }
}

function getNormalizedPlausibleEventBody(fetchOptions) {
  try {
    const body = JSON.parse(fetchOptions.body ?? '{}')

    let name = null
    let domain = null
    let version = null

    if (
      fetchOptions.method === 'POST' &&
      (typeof body?.n === 'string' || typeof body?.name === 'string') &&
      (typeof body?.d === 'string' || typeof body?.domain === 'string')
    ) {
      name = body?.n || body?.name
      domain = body?.d || body?.domain
      version = body?.v || body?.version
    }
    return name && domain ? { name, domain, version } : null
  } catch (_error) {
    // ignore error
  }
}

function startRecordingEventFetchCalls() {
  const interceptions = new Map()

  const originalFetch = window.fetch
  window.fetch = function (url, options = {}) {
    let identifier = null

    const normalizedEventBody = getNormalizedPlausibleEventBody(options)
    if (normalizedEventBody) {
      identifier = normalizedEventBody.name
      interceptions.set(identifier, {
        request: { url, normalizedBody: normalizedEventBody }
      })
    }

    return originalFetch
      .apply(this, arguments)
      .then(async (response) => {
        const eventRequest = interceptions.get(identifier)
        if (eventRequest) {
          const responseClone = response.clone()
          const body = await responseClone.text()
          eventRequest.response = { status: response.status, body }
        }
        return response
      })
      .catch((error) => {
        const eventRequest = interceptions.get(identifier)
        if (eventRequest) {
          eventRequest.error = {
            message: error?.message || 'Unknown error during fetch'
          }
        }
        throw error
      })
  }
  return {
    getInterceptedFetch: (identifier) => interceptions.get(identifier),
    stopRecording: () => {
      window.fetch = originalFetch
    }
  }
}

function isPlausibleOnWindow() {
  return !!window.plausible
}

function isPlausibleInitialized() {
  return window.plausible?.l
}

function getPlausibleVersion() {
  return window.plausible?.v
}

function getPlausibleVariant() {
  return window.plausible?.s
}

async function testPlausibleFunction({ timeoutMs, debug }) {
  // async executor is not a problem in this case, because it's only used for `await delay()` calls
  // not for controlling promise resolution
  // eslint-disable-next-line no-async-promise-executor
  return new Promise(async (resolvePromise) => {
    let plausibleIsOnWindow = isPlausibleOnWindow()
    let plausibleIsInitialized = isPlausibleInitialized()
    let plausibleVersion = getPlausibleVersion()
    let plausibleVariant = getPlausibleVariant()
    let testEvent = {}
    let cookiesConsentResult = {
      handled: null,
      engineLifecycle: 'not-started'
    }

    let resolved = false

    const resolve = (overrides) => {
      resolved = true
      resolvePromise({
        plausibleIsInitialized,
        plausibleIsOnWindow,
        plausibleVersion,
        plausibleVariant,
        testEvent,
        cookiesConsentResult,
        ...overrides
      })
    }

    const timeout = setTimeout(() => {
      resolve({
        error: 'Test Plausible function timeout exceeded'
      })
    }, timeoutMs)

    cookiesConsentResult = initializeCookieConsentEngine({
      debug,
      onConsentDone: (cmp) => {
        if (resolved) return
        cookiesConsentResult = { handled: true, cmp }
      },
      onConsentError: (err) => {
        if (resolved) return
        cookiesConsentResult = { handled: false, error: err }
      },
      onLifecycleUpdate: (lifecycle) => {
        if (resolved) return
        // skips messages that might override consent success or error
        if (cookiesConsentResult.handled !== null) return
        if (lifecycle === 'done') {
          cookiesConsentResult = { handled: true }
        } else {
          cookiesConsentResult.engineLifecycle = lifecycle
        }
      }
    })

    while (!plausibleIsOnWindow) {
      if (isPlausibleOnWindow()) {
        plausibleIsOnWindow = true
      }
      await delay(10)
    }

    while (!plausibleIsInitialized) {
      if (isPlausibleInitialized()) {
        plausibleIsInitialized = true
        plausibleVersion = getPlausibleVersion()
        plausibleVariant = getPlausibleVariant()
      }
      await delay(10)
    }

    window.plausible('verification-agent-test', {
      callback: (testEventCallbackResult) => {
        if (resolved) return
        clearTimeout(timeout)
        resolve({
          testEvent: { callbackResult: testEventCallbackResult }
        })
      }
    })
  })
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

window.verifyPlausibleInstallation = verifyPlausibleInstallation
