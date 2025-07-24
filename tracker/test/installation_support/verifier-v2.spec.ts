import { test, expect } from '@playwright/test'
import { executeVerifyV2 } from '../support/installation-support-playwright-wrappers'
import { initializePageDynamically } from '../support/initialize-page-dynamically'
import { mockManyRequests } from '../support/mock-many-requests'
import { LOCAL_SERVER_ADDR } from '../support/server'
import { tracker_script_version as version } from '../support/test-utils'

const CSP_HOSTS_TO_CHECK = ['plausible.io']

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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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
    await mockManyRequests({
      page,
      path: `https://plausible.io/api/event`,
      awaitedRequestCount: 1,
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      },
      responseDelay: 2000
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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

    await page.goto(url)

    const result = await executeVerifyV2(page, {
      responseHeaders: {},
      debug: true,
      timeoutMs: 1000,
      cspHostsToCheck: CSP_HOSTS_TO_CHECK
    })

    expect(result).toEqual({
      data: {
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
