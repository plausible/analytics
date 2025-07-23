import { checkWordPress } from './check-wordpress'
import { checkGTM } from './check-gtm'
import { checkCookieBanner } from './check-cookie-banner'

/**
 * @param {Object} params
 * @param {string} params.expectedDomain
 * @param {Record<string, string>} params.responseHeaders
 * @param {boolean} params.debug
 * @param {number} params.timeoutMs
 * @returns {Promise<{data: {completed: boolean, plausibleIsInitialized: boolean, plausibleIsOnWindow: boolean, disallowedByCsp: boolean, testEventCallbackResult: any, testEventRequest: any}}}>}
 */

async function verifyPlausibleInstallation({
  timeoutMs,
  expectedDomain,
  responseHeaders,
  debug
}) {
  function log(message) {
    if (debug) console.log('[VERIFICATION v2]', message)
  }

  const disallowedByCsp = checkDisallowedByCSP(responseHeaders)

  const { stopRecording, getEventRequest } = startRecordingEventRequests()

  const {
    plausibleIsInitialized,
    plausibleIsOnWindow,
    testEventCallbackResult,
    error: testPlausibleFunctionError
  } = await testPlausibleFunction({
    timeoutMs
  })

  if (testPlausibleFunctionError) {
    log(
      `There was an error testing plausible function: ${testPlausibleFunctionError}`
    )
  }

  stopRecording()

  const testEventRequest = getEventRequest('verification-agent-test')

  if (!testEventRequest) {
    log(`Could not find recorded test event request`)
  }

  const diagnostics = {
    plausibleIsOnWindow,
    plausibleIsInitialized,
    disallowedByCsp,
    testEventCallbackResult,
    testEventRequest: testEventRequest?.request,
    cookieBannerLikely: checkCookieBanner()
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

function startRecordingEventRequests() {
  const eventRequests = new Map()

  const originalFetch = window.fetch
  window.fetch = function (url, options = {}) {
    console.log('fetch', url, options)
    let identifier = null

    const normalizedEventBody = getNormalizedPlausibleEventBody(options)
    if (normalizedEventBody) {
      identifier = normalizedEventBody.name
      eventRequests.set(identifier, {
        request: { url, normalizedBody: normalizedEventBody }
      })
    }

    return originalFetch
      .apply(this, arguments)
      .then(async (response) => {
        const eventRequest = eventRequests.get(identifier)
        if (eventRequest) {
          const responseClone = response.clone()
          const body = await responseClone.text()
          eventRequest.response = { status: response.status, body }
        }
        return response
      })
      .catch((error) => {
        const eventRequest = eventRequests.get(identifier)
        if (eventRequest) {
          eventRequest.error = {
            message: error?.message || 'Unknown error during fetch'
          }
        }
        throw error
      })
  }
  return {
    getEventRequest: (identifier) => eventRequests.get(identifier),
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

async function testPlausibleFunction({ timeoutMs }) {
  return new Promise(async (_resolve) => {
    let plausibleIsOnWindow = isPlausibleOnWindow()
    let plausibleIsInitialized = isPlausibleInitialized()
    let resolved = false

    function resolve(additionalData) {
      resolved = true
      _resolve({
        plausibleIsInitialized,
        plausibleIsOnWindow,
        ...additionalData
      })
    }

    const timeout = setTimeout(() => {
      resolve({
        error: 'Test event timeout exceeded'
      })
    }, timeoutMs)

    while (!plausibleIsOnWindow) {
      if (isPlausibleOnWindow()) {
        plausibleIsOnWindow = true
      }
    }

    while (!plausibleIsInitialized) {
      if (isPlausibleInitialized()) {
        plausibleIsInitialized = true
      }
    }

    window.plausible('verification-agent-test', {
      callback: (testEventCallbackResult) => {
        if (resolved) return
        clearTimeout(timeout)
        resolve({
          testEventCallbackResult
        })
      }
    })
  })
}

function checkDisallowedByCSP(responseHeaders) {
  // TODO: Implement CSP check
  return false
}

window.verifyPlausibleInstallation = verifyPlausibleInstallation
