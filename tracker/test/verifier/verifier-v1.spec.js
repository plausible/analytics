import { test, expect } from '@playwright/test'
import verify from '../support/verify-playwright-wrapper'
import { delay } from '../support/test-utils'
import { initializePageDynamically } from '../support/initialize-page-dynamically'
import { compileFile } from '../../compiler'

const SOME_DOMAIN = 'somesite.com'

async function mockEventResponseSuccess(page, responseDelay = 0) {
  await page.context().route('**/api/event', async (route) => {
    if (responseDelay > 0) {
      await delay(responseDelay)
    }

    await route.fulfill({
      status: 202,
      contentType: 'text/plain',
      body: 'ok'
    })
  })
}

test.describe('v1 verifier (basic diagnostics)', () => {
  test('correct installation', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)

    // `data.proxyLikely` is mostly expected to be true in tests because
    // any local script src is considered a proxy. More involved behaviour
    // is covered by unit tests under `check-proxy-likely.spec.js`
    expect(result.data.proxyLikely).toBe(true)
  })

  test('missing snippet', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: ''
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(false)
    expect(result.data.callbackStatus).toBe(0)
    expect(result.data.snippetsFoundInHead).toBe(0)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('snippet in body', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `<body><script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script></body>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(0)
    expect(result.data.snippetsFoundInBody).toBe(1)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('figures out well placed snippet in a multi-domain setup', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `<head><script defer data-domain="example.org,example.com,example.net" src="/tracker/js/plausible.local.js"></script></head>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: "example.com"})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('figures out well placed snippet in a multi-domain mismatch', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `<head><script defer data-domain="example.org,example.com,example.net" src="/tracker/js/plausible.local.js"></script></head>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: "example.typo"})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(true)
  })

  test('proxyLikely is false when every snippet starts with an official plausible.io URL', async ({ page }, { testId }) => {
    const prodScriptLocation = 'https://plausible.io/js/'
    
    mockEventResponseSuccess(page)

    // We speed up the test by serving "just some script"
    // (avoiding the event callback delay in verifier)
    const code = await compileFile({
      name: "plausible.local.js",
      globals: {
        "COMPILE_LOCAL": true,
        "COMPILE_PLAUSIBLE_LEGACY_VARIANT": true
      }
    }, { returnCode: true })
    
    await page.context().route(`${prodScriptLocation}**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/javascript',
        body: code
      })
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <head><script defer src="${prodScriptLocation + 'script.js'}" data-domain="${SOME_DOMAIN}"></script></head>
        <body><script defer src="${prodScriptLocation + 'plausible.outbound-links.js'}" data-domain="${SOME_DOMAIN}"></script></body>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN, debug: true})

    expect(result.data.proxyLikely).toBe(false)
  })

  test('counting snippets', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <head>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        </head>
        <body>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        </body>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: "example.com"})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(2)
    expect(result.data.snippetsFoundInBody).toBe(3)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('detects dataDomainMismatch', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="wrong.com" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: 'right.com'})

    expect(result.data.dataDomainMismatch).toBe(true)
  })

  test('dataDomainMismatch is false when data-domain without "www." prefix matches', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="www.right.com" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: 'right.com'})

    expect(result.data.dataDomainMismatch).toBe(false)
  })

})

test.describe('v1 verifier (window.plausible)', () => {
  test('callbackStatus is 404 when /api/event not found', async ({ page }, { testId }) => {
    await page.context().route('**/api/event', async (route) => {
      await route.fulfill({status: 404})
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.callbackStatus).toBe(404)
  })

  test('callBackStatus is 0 when event request times out', async ({ page }, { testId }) => {
    mockEventResponseSuccess(page, 20000)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.callbackStatus).toBe(0)
  })

  test('callBackStatus is -1 when a network error occurs on sending event', async ({ page }, { testId }) => {
    await page.context().route('**/api/event', async (route) => {
      await route.abort()
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN, debug: true})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.callbackStatus).toBe(-1)
  })
})

test.describe('v1 verifier (logging)', () => {
  test('console logs in debug mode', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    let logs = []
    page.context().on('console', msg => msg.type() === 'log' && logs.push(msg.text()))

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN, debug: true})

    expect(logs.find(str => str.includes('Starting snippet detection'))).toContain('[Plausible Verification] Starting snippet detection')
    expect(logs.find(str => str.includes('Checking for Plausible function'))).toContain('[Plausible Verification] Checking for Plausible function')
  })

  test('does not log by default', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    let logs = []
    page.context().on('console', msg => msg.type() === 'log' && logs.push(msg.text()))

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(logs.length).toBe(0)
  })
})
