import { test, expect } from '@playwright/test'
import verify from '../support/verify-playwright-wrapper'
import { delay } from '../support/test-utils'
import { initializePageDynamically } from '../support/initialize-page-dynamically'

const SOME_DOMAIN = 'somesite.com'

async function mockSuccessfulEventResponse(page, responseDelay = 0) {
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

test.describe('legacy verifier', () => {
  test('finds snippet in head and executes plausible function', async ({ page }, { testId }) => {
    mockSuccessfulEventResponse(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})
    
    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
  })

  test('detects dataDomainMismatch', async ({ page }, { testId }) => {
    mockSuccessfulEventResponse(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="wrong.com" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: 'right.com'})
    
    expect(result.data.dataDomainMismatch).toBe(true)
  })

  test('console logs in debug mode', async ({ page }, { testId }) => {
    mockSuccessfulEventResponse(page)

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
    mockSuccessfulEventResponse(page)

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