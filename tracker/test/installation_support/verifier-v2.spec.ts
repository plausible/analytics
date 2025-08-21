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
  timeoutBetweenAttemptsMs: 500
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
          error: undefined
        },
        cookieBannerLikely: false
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
          error: undefined
        },
        cookieBannerLikely: false
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
          error: undefined
        },
        cookieBannerLikely: false
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
        plausibleIsInitialized: true,
        plausibleIsOnWindow: true,
        disallowedByCsp: false,
        plausibleVersion: version,
        plausibleVariant: 'web',
        testEvent: {
          callbackResult: undefined,
          requestUrl: undefined,
          normalizedBody: undefined,
          responseStatus: undefined,
          error: undefined
        },
        cookieBannerLikely: false
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
        responseHeaders
      }),
      page.evaluate(
        ({ targetUrl }) =>
          setTimeout(() => (window.location.href = targetUrl), 250),
        { targetUrl: urlBeta }
      )
    ])
    await expect(page.getByText('beta')).toBeVisible()

    expect(result).toEqual({
      data: {
        attempts: 2,
        completed: true,
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
        cookieBannerLikely: false
      }
    })
  })

  test('there are more than maxAttempts JS navigations', async ({ page }, {
    testId
  }) => {
    const timeoutBetweenAttemptsMs = 100
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
      bodyContent: `
      <script>setTimeout(() => window.location.href = "${urlGamma}", ${
        timeoutBetweenAttemptsMs + 250
      })</script>`
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
        timeoutBetweenAttemptsMs,
        maxAttempts,
        responseHeaders
      }),
      page.evaluate(
        (url) => setTimeout(() => (window.location.href = url), 250),
        urlBeta
      )
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
        plausibleIsOnWindow: true,
        plausibleIsInitialized: undefined,
        plausibleVersion: undefined,
        plausibleVariant: undefined,
        testEvent: {
          error: undefined,
          normalizedBody: undefined,
          requestUrl: undefined,
          responseStatus: undefined
        },
        cookieBannerLikely: false
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
        plausibleIsOnWindow: true,
        plausibleIsInitialized: undefined,
        plausibleVersion: undefined,
        plausibleVariant: undefined,
        testEvent: {
          error: undefined,
          normalizedBody: undefined,
          requestUrl: undefined,
          responseStatus: undefined
        },
        cookieBannerLikely: false
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
        cookieBannerLikely: false
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
      scriptConfig: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track; init(${JSON.stringify(
        {
          domain: 'example.com',
          endpoint: `https://plausible.io/api/event`,
          captureOnLocalhost: true
        }
      )})</script>`,
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
        cookieBannerLikely: false
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
      scriptConfig: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track; init(${JSON.stringify(
        {
          domain: 'example.com',
          endpoint: `/events`,
          captureOnLocalhost: true
        }
      )})</script>`,
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
        cookieBannerLikely: false
      }
    })
  })

  test('using <script type="module"> tag and endpoint: "https://example.com/events"', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track; init(${JSON.stringify(
        {
          domain: 'example.com',
          endpoint: `https://example.com/events`,
          captureOnLocalhost: true
        }
      )})</script>`,
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
        cookieBannerLikely: false
      }
    })
  })

  test('using <script type="module"> tag and invalid endpoint: "invalid:/plausible.io/api/event"', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track; init(${JSON.stringify(
        {
          domain: 'example.com/foobar',
          endpoint: 'invalid:/plausible.io/api/event',
          captureOnLocalhost: true
        }
      )})</script>`,
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
        cookieBannerLikely: false
      }
    })
  })
})
