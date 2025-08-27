/** @typedef {import('../test/support/types').VerifyV2Args} VerifyV2Args */
/** @typedef {import('../test/support/types').VerifyV2Result} VerifyV2Result */
import { checkDisallowedByCSP } from './check-disallowed-by-csp'
import AutoConsent from '../node_modules/@duckduckgo/autoconsent/dist/autoconsent.esm.js'
import { autoconsent } from '../node_modules/@duckduckgo/autoconsent/rules/rules.json'
import { consentomatic } from '../node_modules/@duckduckgo/autoconsent/rules/consentomatic.json'

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

  const [
    {
      plausibleIsInitialized,
      plausibleIsOnWindow,
      plausibleVersion,
      plausibleVariant,
      testEvent,
      error: testPlausibleFunctionError
    },
    cookiesConsentResult
  ] = await Promise.all([
    testPlausibleFunction({
      timeoutMs
    }),
    handleCookieConsent({ timeoutMs: Math.max(timeoutMs - 300, 100) })
  ])

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
  } catch (e) {}
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

async function testPlausibleFunction({ timeoutMs }) {
  return new Promise(async (_resolve) => {
    let plausibleIsOnWindow = isPlausibleOnWindow()
    let plausibleIsInitialized = isPlausibleInitialized()
    let plausibleVersion = getPlausibleVersion()
    let plausibleVariant = getPlausibleVariant()
    let testEvent = {}

    let resolved = false

    function resolve(additionalData) {
      resolved = true
      _resolve({
        plausibleIsInitialized,
        plausibleIsOnWindow,
        plausibleVersion,
        plausibleVariant,
        testEvent,
        ...additionalData
      })
    }

    const timeout = setTimeout(() => {
      resolve({
        error: 'Test Plausible function timeout exceeded'
      })
    }, timeoutMs)

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

async function handleCookieConsent({ timeoutMs, debug }) {
  return new Promise((_resolve) => {
    let resolved = false

    const resolve = (payload) => {
      if (!resolved) {
        resolved = true
        _resolve(payload)
      }
    }

    try {
      let engineLifecycle = null

      const onMessage = (message) => {
        switch (message?.type) {
          case 'autoconsentDone':
            resolve({ handled: true, cmp: message.cmp })
            break
          case 'autoconsentError':
            resolve({
              handled: false,
              error: message.details
            })
            break
          case 'report':
            if (message.state.lifecycle === 'done') {
              resolve({ handled: true })
            } else {
              console.log(message)
              engineLifecycle = message.state.lifecycle
            }
            break
          case undefined:
          default:
            break
        }
      }

      setTimeout(() => {
        if (!resolved) {
          resolve({
            handled: false,
            error: {
              message: 'Time allocated for cookie consent engine exceeded',
              engineLifecycle
            }
          })
        }
      }, timeoutMs)

      const engine = new AutoConsent(
        onMessage,
        {
          enabled: true,
          autoAction: 'optIn',
          disabledCmps: [],
          enablePrehide: false,
          enableCosmeticRules: false,
          enableGeneratedRules: true,
          enableHeuristicDetection: false,
          detectRetries: 2,
          isMainWorld: false,
          prehideTimeout: 0,
          enableFilterList: false,
          visualTest: false,
          logs: {
            lifecycle: debug,
            rulesteps: debug,
            detectionsteps: debug,
            evals: debug,
            errors: debug,
            messages: debug,
            waits: debug
          }
        },
        { autoconsent, consentomatic }
      )
      engineLifecycle = engine.state.lifecycle
    } catch (e) {
      resolve({
        handled: false,
        error: {
          message: 'Error initializing cookie consent engine'
        }
      })
    }
  })
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

window.verifyPlausibleInstallation = verifyPlausibleInstallation
