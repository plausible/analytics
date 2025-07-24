import { test, expect } from '@playwright/test'
import { detect } from '../support/installation-support-playwright-wrappers'
import { initializePageDynamically } from '../support/initialize-page-dynamically'

test.describe('detector.js (tech recognition)', () => {
  test('skips v1 snippet detection by default', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <script src="" data-domain=""></script>
          </head>
        </html>
      `
    })

    const result = await detect(page, {url: url, detectV1: false})

    expect(result.data.v1Detected).toBe(null)
  })

  test('detects WP plugin, WP and GTM', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <link rel="icon" href="https://example.com/wp-content/uploads/favicon.ico" sizes="32x32">
            <meta name="plausible-analytics-version" content="2.3.1">
            <script async src="https://www.googletagmanager.com/gtm.js?id=GTM-123"></script>
          </head>
        </html>
      `
    })

    const result = await detect(page, {url: url, detectV1: false})

    expect(result.data.wordpressPlugin).toBe(true)
    expect(result.data.wordpressLikely).toBe(true)
    expect(result.data.gtmLikely).toBe(true)
  })

  test('No WP plugin, WP or GTM', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      response: '<html><head></head></html>'
    })

    const result = await detect(page, {url: url, detectV1: false})

    expect(result.data.wordpressPlugin).toBe(false)
    expect(result.data.wordpressLikely).toBe(false)
    expect(result.data.gtmLikely).toBe(false)
  })
})

test.describe('detector.js (v1 detection)', () => {
  test('v1Detected is true when v1 plausible exists + detects WP plugin, WP and GTM', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <link rel="icon" href="https://example.com/wp-content/uploads/favicon.ico" sizes="32x32">
            <meta name="plausible-analytics-version" content="2.3.1">
            <script async src="https://www.googletagmanager.com/gtm.js?id=GTM-123"></script>
            <script defer src="/tracker/js/plausible.local.manual.js" data-domain="abc.de"></script>
          </head>
        </html>
      `
    })

    const result = await detect(page, {url: url, detectV1: true})

    expect(result.data.v1Detected).toBe(true)
    expect(result.data.wordpressPlugin).toBe(true)
    expect(result.data.wordpressLikely).toBe(true)
    expect(result.data.gtmLikely).toBe(true)
  })

  test('v1Detected is false when plausible function does not exist', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      response: '<html><head></head></html>'
    })

    const result = await detect(page, {url: url, detectV1: true})

    expect(result.data.v1Detected).toBe(false)
    expect(result.data.wordpressPlugin).toBe(false)
    expect(result.data.wordpressLikely).toBe(false)
    expect(result.data.gtmLikely).toBe(false)
  })

  test('v1Detected is false when v2 plausible installed', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: {
        domain: 'abc.de',
        captureOnLocalhost: false
      }
    })

    const result = await detect(page, {url: url, detectV1: true})

    expect(result.data.v1Detected).toBe(false)
  })
})
