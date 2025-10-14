import { test, expect } from '@playwright/test'
import { executeVerifyV2 } from '../support/installation-support-playwright-wrappers'
import { initializePageDynamically } from '../support/initialize-page-dynamically'
import { mockManyRequests } from '../support/mock-many-requests'
import { LOCAL_SERVER_ADDR } from '../support/server'
import { tracker_script_version as version } from '../support/test-utils'

const DEFAULT_VERIFICATION_OPTIONS = {
  responseHeaders: {},
  debug: true,
  timeoutMs: 1000,
  cspHostToCheck: 'plausible.io',
  maxAttempts: 2,
  timeoutBetweenAttemptsMs: 500,
  trackerScriptSelector: `script[src^="/tracker/js/plausible-web.js"]`
}

const incompleteCookiesConsentResult = {
  engineLifecycle: expect.stringMatching(/started|initialized/),
  handled: null
}

test.describe('installed plausible web variant', () => {
  test('using provided snippet', async ({ page }, { testId }) => {
    await mockManyRequests({
      page,
      path: `https://plausible.io/api/event`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        domain: 'example.com',
        endpoint: `https://plausible.io/api/event`,
        captureOnLocalhost: true
      },
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: true,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: { status: 202 },
          requestUrl: 'https://plausible.io/api/event',
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 202,
          error: undefined,
          testPlausibleFunctionError: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('using provided snippet and the events endpoint responds slower than the timeout', async ({
    page
  }, { testId }) => {
    const responseDelayMs = 2000
    const timeoutMs = 1000
    await mockManyRequests({
      page,
      path: `https://plausible.io/api/event`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      },
      responseDelay: responseDelayMs
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        domain: 'example.com',
        endpoint: `https://plausible.io/api/event`,
        captureOnLocalhost: true
      },
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders,
      timeoutMs
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: true,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: undefined,
          requestUrl: 'https://plausible.io/api/event',
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: undefined,
          error: undefined,
          testPlausibleFunctionError: 'Test Plausible function timeout exceeded'
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('using provided snippet and the events endpoint responds with 400', async ({
    page
  }, { testId }) => {
    await mockManyRequests({
      page,
      path: `https://plausible.io/api/event`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 400,
        contentType: 'text/plain',
        body: 'Bad Request'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        domain: 'example.com',
        endpoint: `https://plausible.io/api/event`,
        captureOnLocalhost: true
      },
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: true,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: { status: 400 },
          requestUrl: 'https://plausible.io/api/event',
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 400,
          error: undefined,
          testPlausibleFunctionError: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('using provided snippet and captureOnLocalhost: false', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        domain: 'example.com/foobar',
        endpoint: 'https://plausible.io/api/event',
        captureOnLocalhost: false
      },
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: true,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: 'undefined or null',
          requestUrl: undefined,
          normalizedBody: undefined,
          responseStatus: undefined,
          error: undefined,
          testPlausibleFunctionError: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('there is a JS navigation immediately on page load to a page with the provided snippet', async ({
    page
  }, { testId }) => {
    const { url: urlBeta } = await initializePageDynamically(page, {
      path: '/beta',
      testId,
      scriptConfig: {
        domain: 'example.com/beta',
        endpoint: 'https://plausible.io/api/event',
        captureOnLocalhost: true
      },
      bodyContent: 'beta'
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: '', // no tracker on initial page
      bodyContent: 'alfa'
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    await expect(page.getByText('alfa')).toBeVisible()

    const [result, _] = await Promise.all([
      executeVerifyV2(page, {
        ...DEFAULT_VERIFICATION_OPTIONS,
        timeoutMs: 1500,
        responseHeaders
      }),
      (async () => {
        // start navigation timer only when the verifier code has been added to the page
        await page.waitForFunction(`() => !!window.verifyPlausibleInstallation`)
        await page.evaluate(
          ({ targetUrl }) => {
            setTimeout(() => {
              window.location.href = targetUrl
            }, 500)
          },
          { targetUrl: urlBeta }
        )
      })()
    ])
    await expect(page.getByText('beta')).toBeVisible()

    expect(result).toEqual({
      data: {
        attempts: 2,
        completed: true,
        trackerIsInHtml: true,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: { status: 202 },
          requestUrl: 'https://plausible.io/api/event',
          normalizedBody: {
            domain: 'example.com/beta',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 202,
          error: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('there are more than maxAttempts JS navigations', async ({ page }, {
    testId
  }) => {
    const maxAttempts = 2

    const { url: urlGamma } = await initializePageDynamically(page, {
      path: '/gamma',
      testId,
      scriptConfig: {
        domain: 'example.com/gamma',
        endpoint: 'https://plausible.io/api/event',
        captureOnLocalhost: true
      },
      bodyContent: 'gamma'
    })

    const { url: urlBeta } = await initializePageDynamically(page, {
      path: '/beta',
      testId,
      scriptConfig: '', // no tracker
      bodyContent: 'beta'
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: '', // no tracker
      bodyContent: 'alfa'
    })
    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    await expect(page.getByText('alfa')).toBeVisible()

    const [result] = await Promise.all([
      executeVerifyV2(page, {
        ...DEFAULT_VERIFICATION_OPTIONS,
        timeoutMs: 1500,
        timeoutBetweenAttemptsMs: 100,
        maxAttempts,
        responseHeaders
      }),
      (async () => {
        // start navigation timer only when the verifier code has been added to the page
        await page.waitForFunction(`() => !!window.verifyPlausibleInstallation`)
        await page.evaluate(
          ({ targetUrl }) => {
            setTimeout(() => {
              console.debug(`navigation 1`)
              window.location.href = targetUrl
            }, 500)
          },
          { targetUrl: urlBeta }
        )
        await expect(page.getByText('beta')).toBeVisible()
        // start navigation timer only when the verifier code has been added to the page
        await page.waitForFunction(`() => !!window.verifyPlausibleInstallation`)
        await page.evaluate(
          ({ targetUrl }) => {
            setTimeout(() => {
              window.location.href = targetUrl
            }, 500)
          },
          { targetUrl: urlGamma }
        )
      })()
    ])

    await expect(page.getByText('gamma')).toBeVisible()

    expect(result).toEqual({
      data: {
        completed: false,
        error: {
          message:
            'page.evaluate: Execution context was destroyed, most likely because of a navigation.'
        }
      }
    })
  })

  test('using provided snippet but disallowed by CSP', async ({ page }, {
    testId
  }) => {
    await mockManyRequests({
      page,
      path: `https://plausible.io/api/event`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        domain: 'example.com',
        endpoint: `https://plausible.io/api/event`,
        captureOnLocalhost: true
      },
      bodyContent: '',
      headers: {
        'content-security-policy': "default-src 'self'; img-src 'self'"
      }
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        disallowedByCsp: true,
        trackerIsInHtml: true,
        plausibleIsOnWindow: true,
        plausibleIsInitialized: undefined,
        plausibleVersion: undefined,
        plausibleVariant: undefined,
        testEvent: {
          error: undefined,
          normalizedBody: undefined,
          requestUrl: undefined,
          responseStatus: undefined,
          testPlausibleFunctionError: 'Test Plausible function timeout exceeded'
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test(`using provided snippet and there is a strict CSP without 'unsafe-inline'`, async ({
    page
  }, { testId }) => {
    const endpoint = `${LOCAL_SERVER_ADDR}/api/event`
    const cspHostToCheck = LOCAL_SERVER_ADDR.replace('http://', '')
    const headers = {
      // 'unsafe-inline' is needed to allow the bootstrapper snippet to be executed
      'content-security-policy': `default-src 'self'; script-src ${cspHostToCheck}; connect-src ${cspHostToCheck}`
    }

    await mockManyRequests({
      page,
      path: endpoint,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        endpoint,
        domain: 'example.com',
        captureOnLocalhost: true
      },
      bodyContent: '',
      headers
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      cspHostToCheck,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        disallowedByCsp: false, // scripts from our domain are allowed, but the inline sourceless snippet can't run because 'unsafe-inline' is not present in the CSP
        trackerIsInHtml: true,
        plausibleIsOnWindow: true,
        plausibleIsInitialized: undefined,
        plausibleVersion: undefined,
        plausibleVariant: undefined,
        testEvent: {
          error: undefined,
          normalizedBody: undefined,
          requestUrl: undefined,
          responseStatus: undefined,
          testPlausibleFunctionError: 'Test Plausible function timeout exceeded'
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test(`using provided snippet and there is a strict CSP with 'unsafe-inline'`, async ({
    page
  }, { testId }) => {
    const endpoint = `${LOCAL_SERVER_ADDR}/api/event`
    const cspHostToCheck = LOCAL_SERVER_ADDR.replace('http://', '')
    const headers = {
      // 'unsafe-inline' is needed to allow the bootstrapper snippet to be executed
      'content-security-policy': `default-src 'self'; script-src 'unsafe-inline' ${cspHostToCheck}; connect-src ${cspHostToCheck}`
    }

    await mockManyRequests({
      page,
      path: endpoint,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        endpoint,
        domain: 'example.com',
        captureOnLocalhost: true
      },
      bodyContent: '',
      headers
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      cspHostToCheck,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: true,
        disallowedByCsp: false,
        plausibleIsOnWindow: true,
        plausibleIsInitialized: true,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: { status: 202 },
          requestUrl: `${LOCAL_SERVER_ADDR}/api/event`,
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 202
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })
})

test.describe('installed plausible esm variant', () => {
  test('using <script type="module"> tag', async ({ page }, { testId }) => {
    await mockManyRequests({
      page,
      path: `https://plausible.io/api/event`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: /* HTML */ `<script type="module">
        import { init, track } from '/tracker/js/npm_package/plausible.js'
        window.init = init
        window.track = track
        init(
          ${JSON.stringify({
            domain: 'example.com',
            endpoint: `https://plausible.io/api/event`,
            captureOnLocalhost: true
          })}
        )
      </script>`,
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: false,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'npm',
        testEvent: {
          callbackResult: { status: 202 },
          requestUrl: 'https://plausible.io/api/event',
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 202,
          error: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('using <script type="module"> tag and endpoint: "/events"', async ({
    page
  }, { testId }) => {
    await mockManyRequests({
      page,
      path: `${LOCAL_SERVER_ADDR}/events`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: /* HTML */ `<script type="module">
        import { init, track } from '/tracker/js/npm_package/plausible.js'
        window.init = init
        window.track = track
        init(
          ${JSON.stringify({
            domain: 'example.com',
            endpoint: `/events`,
            captureOnLocalhost: true
          })}
        )
      </script>`,
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: false,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'npm',
        testEvent: {
          callbackResult: { status: 202 },
          requestUrl: '/events',
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 202,
          error: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('using <script type="module"> tag and endpoint: "https://example.com/events"', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: /* HTML */ `<script type="module">
        import { init, track } from '/tracker/js/npm_package/plausible.js'
        window.init = init
        window.track = track
        init(
          ${JSON.stringify({
            domain: 'example.com',
            endpoint: `https://example.com/events`,
            captureOnLocalhost: true
          })}
        )
      </script>`,
      bodyContent: ''
    })

    await mockManyRequests({
      page,
      path: `https://example.com/events`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 500,
        contentType: 'text/plain',
        body: 'Unknown error'
      }
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: false,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'npm',
        testEvent: {
          callbackResult: { status: 500 },
          requestUrl: 'https://example.com/events',
          normalizedBody: {
            domain: 'example.com',
            name: 'verification-agent-test',
            version
          },
          responseStatus: 500,
          error: undefined
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })

  test('using <script type="module"> tag and invalid endpoint: "invalid:/plausible.io/api/event"', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: /* HTML */ `<script type="module">
        import { init, track } from '/tracker/js/npm_package/plausible.js'
        window.init = init
        window.track = track
        init(
          ${JSON.stringify({
            domain: 'example.com/foobar',
            endpoint: 'invalid:/plausible.io/api/event',
            captureOnLocalhost: true
          })}
        )
      </script>`,
      bodyContent: ''
    })

    const response = await page.goto(url)
    const responseHeaders = response?.headers() ?? {}

    const result = await executeVerifyV2(page, {
      ...DEFAULT_VERIFICATION_OPTIONS,
      responseHeaders
    })

    expect(result).toEqual({
      data: {
        attempts: 1,
        completed: true,
        trackerIsInHtml: false,
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'npm',
        testEvent: {
          callbackResult: {
            error: expect.objectContaining({ message: 'Failed to fetch' })
          },
          requestUrl: 'invalid:/plausible.io/api/event',
          normalizedBody: {
            domain: 'example.com/foobar',
            name: 'verification-agent-test',
            version
          },
          responseStatus: undefined,
          error: { message: 'Failed to fetch' }
        },
        cookiesConsentResult: incompleteCookiesConsentResult
      }
    })
  })
})

test.describe('opts in on cookie banners', () => {
  for (const { url, expectedCookiesConsentResult } of [
    {
      url: `${LOCAL_SERVER_ADDR}/cookies-onetrust.html`,
      expectedCookiesConsentResult: {
        cmp: 'Onetrust',
        handled: true
      }
    },
    {
      url: `${LOCAL_SERVER_ADDR}/cookies-iubenda.html`,
      expectedCookiesConsentResult: {
        cmp: 'iubenda',
        handled: true
      }
    },
    {
      url: `${LOCAL_SERVER_ADDR}/cookies-cookiebot.html`,
      expectedCookiesConsentResult: {
        cmp: 'cookiebot',
        handled: true
      }
    },
    {
      url: `${LOCAL_SERVER_ADDR}/cookies-quantcast.html`,
      expectedCookiesConsentResult: {
        cmp: 'quantcast',
        handled: true
      }
    }
  ]) {
    test(`accepts cookies of cmp ${expectedCookiesConsentResult.cmp}`, async ({
      page
    }) => {
      const response = await page.goto(url)
      const responseHeaders = response?.headers() ?? {}

      const result = await executeVerifyV2(page, {
        ...DEFAULT_VERIFICATION_OPTIONS,
        timeoutMs: 2000,
        responseHeaders
      })

      expect(result.data).toEqual(
        expect.objectContaining({
          cookiesConsentResult: expectedCookiesConsentResult
        })
      )
    })
  }
})
