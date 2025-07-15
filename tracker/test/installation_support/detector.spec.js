import { test, expect } from '@playwright/test'
import { detect } from '../support/installation-support-playwright-wrappers'
import { initializePageDynamically } from '../support/initialize-page-dynamically'

test.describe('detector.js (basic diagnostics)', () => {
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

    expect(result.data.v1Detected).toBe(false)
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
