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
    test('tracks download when link opens in same tab', async ({ page }, { testId }) => {
      const filePath = '/file.csv'
      const { getRequestList } = await mockManyRequests({
        page,
        path: `${LOCAL_SERVER_ADDR}${filePath}`,
        fulfill: {
          contentType: 'text/csv'
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

    test('tracks download when link opens in new tab (target="__blank")', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
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

    test('tracks download when link opens in new tab (ControlOrMeta + click)', async ({
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

    test('tracks download when link child element is clicked', async ({
      page
    }, { testId }) => {
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
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

    test('tracks download without delaying navigation, relying on fetch options.keepalive to deliver tracking events', async ({
      page
    }, { testId }) => {
      const eventsApiMock = await mockManyRequests({
        page,
        path: '**/api/event',
        countOfRequestsToAwait: 1,
        responseDelay: 500
      })
      const pdfUrl = 'https://example.com/downloads/file.pdf'
      const pdfMock = await mockManyRequests({
        page,
        path: pdfUrl,
        fulfill: {
          contentType: 'application/pdf'
        },
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: {
              ...DEFAULT_CONFIG,
              fileDownloads: true,
              autoCapturePageviews: false
            },
            legacy:
              '<script id="plausible" defer src="/tracker/js/plausible.file-downloads.local.manual.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${pdfUrl}">Download</a>`
      })
      await page.goto(url)
      await page.click('a')
      const [
        { trackingRequestList, trackingResponseTime },
        { downloadMockRequestList, downloadRequestTime }
      ] = await Promise.all([
        eventsApiMock.getRequestList().then((requestList) => ({
          trackingRequestList: requestList,
          trackingResponseTime: Date.now()
        })),
        pdfMock.getRequestList().then((requestList) => ({
          downloadMockRequestList: requestList,
          downloadRequestTime: Date.now()
        }))
      ])

      expect(downloadRequestTime).toBeLessThan(trackingResponseTime)
      expect(downloadMockRequestList).toHaveLength(1)
      expect(trackingRequestList).toEqual([
        expect.objectContaining({
          n: 'File Download',
          p: {
            url: pdfUrl
          }
        })
      ])
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
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; window.init = init; window.track = track; init(${JSON.stringify(
              config
            )})</script>`
          },
          mode
        ),
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
  test('tracks and starts exactly one download on link click', async ({
    page
  }, { testId }) => {
    const eventsApiMock = await mockManyRequests({
      page,
      path: '**/api/event',
      countOfRequestsToAwait: 2,
      mockRequestTimeoutMs: 2000
    })
    const filePath = '/file.csv'
    const downloadableFileMock = await mockManyRequests({
      page,
      path: `${LOCAL_SERVER_ADDR}${filePath}`,
      fulfill: {
        contentType: 'text/csv'
      },
      countOfRequestsToAwait: 2,
      mockRequestTimeoutMs: 2000
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js"></script>',
      bodyContent: `<a href="${filePath}">📥</a>`
    })
    await page.goto(url)
    await page.click('a')
    const [downloadRequests, eventsApiRequests] = await Promise.all([
      downloadableFileMock.getRequestList(),
      eventsApiMock.getRequestList()
    ])
    expect(downloadRequests).toHaveLength(1)
    expect(eventsApiRequests).toEqual([
      expect.objectContaining({
        n: 'File Download',
        p: {
          url: `${LOCAL_SERVER_ADDR}${filePath}`
        }
      })
    ])
  })

  for (const { fulfill } of [
    {
      fulfill: {
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      }
    },
    {
      fulfill: {
        status: 400,
        contentType: 'text/plain',
        body: 'Bad Request'
      }
    }
  ]) {
    test(`tracking delays navigation until the tracking request has finished (with status: ${fulfill.status})`, async ({
      page
    }, { testId }) => {
      const eventsApiMock = await mockManyRequests({
        page,
        path: '**/api/event',
        fulfill,
        countOfRequestsToAwait: 1,
        responseDelay: 1000
      })
      const filePath = '/file.csv'
      const downloadableFileMock = await mockManyRequests({
        page,
        path: `${LOCAL_SERVER_ADDR}${filePath}`,
        fulfill: {
          contentType: 'text/csv'
        },
        countOfRequestsToAwait: 1,
        mockRequestTimeoutMs: 1000
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig:
          '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js"></script>',
        bodyContent: `<a href="${filePath}">📥</a>`
      })
      await page.goto(url)

      const navigationPromise = page.waitForRequest(filePath, {
        timeout: 2000
      })
      const trackingPromise = page.waitForResponse('**/api/event', {
        timeout: 2000
      })

      await page.click('a')
      const [trackingResponseTime, navigationTime] = await Promise.all([
        trackingPromise.then(Date.now),
        navigationPromise.then(Date.now)
      ])
      await expect(downloadableFileMock.getRequestList()).resolves.toHaveLength(
        1
      )
      expect(trackingResponseTime).toBeLessThanOrEqual(navigationTime)
      await expect(eventsApiMock.getRequestList()).resolves.toEqual([
        expect.objectContaining({
          n: 'File Download',
          p: {
            url: `${LOCAL_SERVER_ADDR}${filePath}`
          }
        })
      ])
    })
  }

  test('if the tracking requests delays navigation for more than 5s, it navigates anyway, without waiting for the request to resolve ', async ({
    page
  }, { testId }) => {
    test.setTimeout(20000)
    await mockManyRequests({
      page,
      path: '**/api/event',
      countOfRequestsToAwait: 1,
      responseDelay: 6000
    })
    const filePath = '/file.csv'
    const downloadableFileMock = await mockManyRequests({
      page,
      path: `${LOCAL_SERVER_ADDR}${filePath}`,
      fulfill: {
        contentType: 'text/csv'
      },
      countOfRequestsToAwait: 1,
      mockRequestTimeoutMs: 1000
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.file-downloads.local.manual.js"></script>',
      bodyContent: `<a href="${filePath}">📥</a>`
    })
    await page.goto(url)
    const navigationPromise = page.waitForRequest(filePath, {
      timeout: 7000
    })
    const trackingPromise = page.waitForResponse('**/api/event', {
      timeout: 7000
    })
    await page.click('a')
    const [trackingResponseTime, navigationTime] = await Promise.all([
      trackingPromise.then(Date.now).catch(Date.now),
      navigationPromise.then(Date.now)
    ])
    await expect(downloadableFileMock.getRequestList()).resolves.toHaveLength(1)
    expect(navigationTime).toBeLessThan(trackingResponseTime)
  })
})
