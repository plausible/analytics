import {
  expectPlausibleInAction,
  isPageviewEvent,
  isEngagementEvent,
  switchByMode
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

for (const mode of ['legacy', 'web']) {
  test.describe(`file downloads feature legacy/v2 parity (${mode})`, () => {
    test('sends event and starts exactly one download', async ({ page }, {
      testId
    }) => {
      const filePath = '/file.csv'
      const { getRequestList } = await mockManyRequests({
        page,
        path: `${LOCAL_SERVER_ADDR}${filePath}`,
        fulfill: {
          contentType: 'text/csv'
        },
        countOfRequestsToAwait: 2
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: true },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js"></script>'
          },
          mode
        ),
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

    test('sends event and starts exactly one download when link opens in new tab (target="__blank")', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
        fulfill: {
          contentType: 'application/pdf'
        },
        countOfRequestsToAwait: 2
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: true },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${pdfUrl}" target="__blank">📥</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [{ n: 'File Download', p: { url: pdfUrl } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(pdfMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('sends event and starts exactly one download when link opens in new tab (ControlOrMeta + click)', async ({
      page,
      browserName
    }, { testId }) => {
      test.skip(
        browserName === 'webkit',
        'does not start downloads properly with such clicks (works when testing manually in macOS Safari)'
      )
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
        fulfill: {
          contentType: 'application/pdf'
        },
        countOfRequestsToAwait: 2
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: true },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${pdfUrl}">📥</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a', { modifiers: ['ControlOrMeta'] }),
        expectedRequests: [{ n: 'File Download', p: { url: pdfUrl } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(pdfMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('sends event and starts download when link child is clicked', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
        fulfill: {
          contentType: 'application/pdf'
        },
        countOfRequestsToAwait: 2
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: true },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js"></script>'
          },
          mode
        ),
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

    test('event.props.url is stripped of query parameters', async ({ page }, {
      testId
    }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: `${pdfUrl}*`,
        fulfill: {
          contentType: 'application/pdf'
        },
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: true },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${pdfUrl}?user=foo%secret=123">Download PDF</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [{ n: 'File Download', p: { url: pdfUrl } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expect(pdfMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('does not track iso files by default', async ({ page }, {
      testId
    }) => {
      await mockManyRequests({
        page,
        path: 'https://example.com/file.iso',
        fulfill: {
          contentType: 'application/octet-stream'
        },
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: true },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js"></script>'
          },
          mode
        ),
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
        fulfill: {
          contentType: 'text/csv'
        },
        countOfRequestsToAwait: 1
      })
      const isoMock = await mockManyRequests({
        page,
        path: isoFileURL,
        fulfill: {
          contentType: 'application/octet-stream'
        },
        countOfRequestsToAwait: 1
      })

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, fileDownloads: ['iso'] },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.js" file-types="iso"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${isoFileURL}" target="__blank">📥</a><a href="${csvFileURL}" target="__blank">📥</a>`
      })
      await page.goto(url)
      await expectPlausibleInAction(page, {
        action: () => page.click(`a[href="${csvFileURL}"]`),
        refutedRequests: [{ n: 'File Download' }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
      await expect(csvMock.getRequestList()).resolves.toHaveLength(1)

      await expectPlausibleInAction(page, {
        action: () => page.click(`a[href="${isoFileURL}"]`),
        expectedRequests: [{ n: 'File Download', p: { url: isoFileURL } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
      await expect(isoMock.getRequestList()).resolves.toHaveLength(1)
    })
  })
}

for (const mode of ['web', 'esm']) {
  test.describe(`file downloads feature v2-specific (${mode})`, () => {
    test('malformed `fileDownloads: "iso"` option enables the feature with default file types', async ({
      page
    }, { testId }) => {
      const csvFileURL = `https://example.com/file.csv`
      const isoFileURL = `https://example.com/file.iso`

      const csvMock = await mockManyRequests({
        page,
        path: csvFileURL,
        fulfill: {
          contentType: 'text/csv'
        },
        countOfRequestsToAwait: 1
      })
      const isoMock = await mockManyRequests({
        page,
        path: isoFileURL,
        fulfill: {
          contentType: 'application/octet-stream'
        },
        countOfRequestsToAwait: 1
      })

      const config = {
        ...DEFAULT_CONFIG,
        fileDownloads: 'iso'
      }
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode({
          web: config,
          esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track; init(${JSON.stringify(
            config
          )})</script>`
        }, mode),
        bodyContent: `<a href="${isoFileURL}" target="__blank">📥</a><a href="${csvFileURL}" target="__blank">📥</a>`
      })
      await page.goto(url)
      await expectPlausibleInAction(page, {
        action: () => page.click(`a[href="${csvFileURL}"]`),
        expectedRequests: [{ n: 'File Download', p: { url: csvFileURL } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
      await expect(csvMock.getRequestList()).resolves.toHaveLength(1)

      await expectPlausibleInAction(page, {
        action: () => page.click(`a[href="${isoFileURL}"]`),
        refutedRequests: [{ n: 'File Download' }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
      await expect(isoMock.getRequestList()).resolves.toHaveLength(1)
    })
  })
}

test.describe('file downloads feature when using legacy .compat extension', () => {
  for (const { caseName, fulfill } of [
    {
      caseName: 'if event sending is slow, starts exactly one download',
      fulfill: {
        status: 200,
        contentType: 'text/plain',
        body: 'ok'
      }
    },
    {
      caseName: 'if event sending fails, starts exactly one download',
      fulfill: {
        status: 400,
        contentType: 'text/plain',
        body: 'Bad Request'
      }
    }
  ])
    test(caseName, async ({ page }, { testId }) => {
      test.setTimeout(20000)
      const filePath = '/file.csv'
      const downloadableFileMock = await mockManyRequests({
        page,
        path: `${LOCAL_SERVER_ADDR}${filePath}`,
        fulfill: {
          contentType: 'text/csv'
        },
        countOfRequestsToAwait: 2,
        mockRequestTimeoutMs: 10000
      })
      const eventsApiMock = await mockManyRequests({
        page,
        path: '/api/event',
        fulfill,
        responseDelay: 3000,
        countOfRequestsToAwait: 2,
        mockRequestTimeoutMs: 7000
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js"></script>',
        bodyContent: `<a href="${filePath}">📥</a>`
      })
      await page.goto(url)
      await page.click('a')

      await Promise.all([
        expect(eventsApiMock.getRequestList()).resolves.toEqual([
          expect.objectContaining({
            n: 'File Download'
          })
        ]),
        expect(downloadableFileMock.getRequestList()).resolves.toHaveLength(1)
      ])
    })
})