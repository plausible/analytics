import {
  metaKey,
  expectPlausibleInAction,
  isPageviewEvent,
  isEngagementEvent
} from './support/test-utils'
import { expect, test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import { initializePageDynamically } from './support/initialize-page-dynamically'
import { ScriptConfig } from './support/types'
import { mockManyRequests } from './support/mock-many-requests'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

for (const mode of ['legacy', 'plausible-web']) {
  test.describe(`file downloads feature (${mode})`, () => {
    test('sends event and does not start download when link opens in new tab', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          mode === 'legacy'
            ? '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.manual.js"></script>'
            : { ...DEFAULT_CONFIG, fileDownloads: true },
        bodyContent: `<a href="${pdfUrl}">📥</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a', { modifiers: [metaKey()] }),
        expectedRequests: [{ n: 'File Download', p: { url: pdfUrl } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(pdfMock.getRequestList()).resolves.toHaveLength(0)
    })

    test('sends event and starts download when link child is clicked', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          mode === 'legacy'
            ? '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.manual.js"></script>'
            : { ...DEFAULT_CONFIG, fileDownloads: true },
        bodyContent: `<a href="${pdfUrl}"><div><span>📥</span></div></a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('span'),
        expectedRequests: [{ n: 'File Download', p: { url: pdfUrl } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(pdfMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('sends event with the url stripped of query parameters', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: `${pdfUrl}*`,
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          mode === 'legacy'
            ? '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.manual.js"></script>'
            : { ...DEFAULT_CONFIG, fileDownloads: true },
        bodyContent: `<a href="${pdfUrl}?secret=123&user=foo">Download PDF</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [{ n: 'File Download', p: { url: pdfUrl } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(pdfMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('starts download only once', async ({ page }, { testId }) => {
      const filePath = '/file.csv'
      const { getRequestList } = await mockManyRequests({
        page,
        path: `${LOCAL_SERVER_ADDR}${filePath}`,
        countOfRequestsToAwait: 2
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          mode === 'legacy'
            ? '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js"></script>'
            : { ...DEFAULT_CONFIG, fileDownloads: true },
        bodyContent: `<a href="${filePath}">📥</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [
          { n: 'File Download', p: { url: `${LOCAL_SERVER_ADDR}${filePath}` } }
        ],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(getRequestList()).resolves.toHaveLength(1)
    })

    test('does not track iso files by default', async ({ page }, {
      testId
    }) => {
      await mockManyRequests({
        page,
        path: `https://example.com/file.iso`,
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          mode === 'legacy'
            ? '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js"></script>'
            : { ...DEFAULT_CONFIG, fileDownloads: true },
        bodyContent: `<a href="https://example.com/file.iso">📥</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        refutedRequests: [{ n: 'File Download' }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('respects file download whitelist ["iso"]', async ({ page }, {
      testId
    }) => {
      const csvFileURL = `https://example.com/file.csv`
      const isoFileURL = `https://example.com/file.iso`
      const csvMock = await mockManyRequests({
        page,
        path: csvFileURL,
        countOfRequestsToAwait: 1
      })
      const isoMock = await mockManyRequests({
        page,
        path: isoFileURL,
        countOfRequestsToAwait: 1
      })

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          mode === 'legacy'
            ? '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js" file-types="iso"></script>'
            : { ...DEFAULT_CONFIG, fileDownloads: true },
        bodyContent: `<a href="${isoFileURL}">📥</a><a href="${csvFileURL}">📥</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () =>
          page.click(`a[href="${isoFileURL}"]`, { modifiers: [metaKey()] }),
        expectedRequests: [{ n: 'File Download', p: { url: isoFileURL } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
      await expect(isoMock.getRequestList()).resolves.toHaveLength(0)
      await expectPlausibleInAction(page, {
        action: () =>
          page.click(`a[href="${csvFileURL}"]`, { modifiers: [metaKey()] }),
        refutedRequests: [{ n: 'File Download' }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
      await expect(csvMock.getRequestList()).resolves.toHaveLength(0)
    })
  })
}

test.describe('file downloads feature edge cases (plausible-npm)', () => {
  test('`fileDownloads: "iso"` malformed option still enables the feature with default file types', async ({
    page
  }, { testId }) => {
    const csvFileURL = `https://example.com/file.csv`
    const isoFileURL = `https://example.com/file.iso`

    const csvMock = await mockManyRequests({
      page,
      path: csvFileURL,
      countOfRequestsToAwait: 1
    })
    const isoMock = await mockManyRequests({
      page,
      path: isoFileURL,
      countOfRequestsToAwait: 1
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track</script>`,
      bodyContent: `<a href="${isoFileURL}">📥</a><a href="${csvFileURL}">📥</a>`
    })
    await page.goto(url)
    await page.evaluate(
      (config) => {
        ;(window as any).init(config)
      },
      {
        ...DEFAULT_CONFIG,
        fileDownloads: 'iso' // malformed option
      }
    )

    await expectPlausibleInAction(page, {
      action: () =>
        page.click(`a[href="${csvFileURL}"]`, { modifiers: [metaKey()] }),
      expectedRequests: [{ n: 'File Download', p: { url: csvFileURL } }],
      shouldIgnoreRequest: [isEngagementEvent]
    })
    await expect(csvMock.getRequestList()).resolves.toHaveLength(0)

    await expectPlausibleInAction(page, {
      action: () =>
        page.click(`a[href="${isoFileURL}"]`, { modifiers: [metaKey()] }),
      refutedRequests: [{ n: 'File Download' }],
      shouldIgnoreRequest: [isEngagementEvent]
    })
    await expect(isoMock.getRequestList()).resolves.toHaveLength(0)
  })
})
