import { mockRequest, metaKey, expectPlausibleInAction } from './support/test-utils'
import { expect, test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'

test.describe('legacy file-downloads extension', () => {
  test('sends event and does not start download when link opens in new tab', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = await page.locator('#link').getAttribute('href')

    const downloadRequestMock = mockRequest(page, downloadURL)

    await expectPlausibleInAction(page, {
      action: () => page.click('#link', { modifiers: [metaKey()] }),
      expectedRequests: [{n: 'File Download', p: { url: downloadURL }}]
    })

    expect(await downloadRequestMock, "should not make download request").toBeNull()
  })

  test('sends event and starts download when link child is clicked', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = await page.locator('#link').getAttribute('href')

    const downloadRequestMock = mockRequest(page, downloadURL)

    await expectPlausibleInAction(page, {
      action: () => page.click('#link-child'),
      expectedRequests: [{n: 'File Download', p: { url: downloadURL }}]
    })

    expect((await downloadRequestMock).url()).toContain(downloadURL)
  })

  test('sends File Download event with query-stripped url property', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = await page.locator('#link-query').getAttribute('href')

    await expectPlausibleInAction(page, {
      action: () => page.click('#link-query'),
      expectedRequests: [{n: 'File Download', p: { url: downloadURL.split("?")[0] }}]
    })
  })

  test('starts download only once', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = LOCAL_SERVER_ADDR + '/' + await page.locator('#local-download').getAttribute('href')
    const timeToWaitMs = 3000
    let requestCount = 0
    await page.route(downloadURL, async (route) => {
      requestCount++
      await route.fulfill({
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      })
    })
    await page.click('#local-download')
    await new Promise(resolve => setTimeout(resolve, timeToWaitMs))
    expect(requestCount).toBe(1)
  })
})


test.describe('file downloads', () => {
  test.beforeEach(({ page }) => {
    // Mock file download requests
    mockRequest(page, 'https://awesome.website.com/file.iso')
  })

  const DEFAULT_CONFIG = {
    domain: 'example.com',
    endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
    captureOnLocalhost: true,
    autoCapturePageviews: false
  }

  async function openPage(page, config) {
    await page.goto(`/file-download-plausible-web.html`)
    await page.waitForFunction('window.plausible !== undefined')

    await page.evaluate((config) => {
      window.plausible.init(config)
    }, { ...DEFAULT_CONFIG, ...config })
  }

  test('does not track iso files by default', async ({ page }) => {
    await openPage(page, { fileDownloads: true })

    await expectPlausibleInAction(page, {
      action: () => page.click('#file-download-iso', { modifiers: [metaKey()] }),
      expectedRequests: [],
      rejectRequests: [{ n: 'File Download' }],
    })
  })

  test('tracks iso but not pdf files when config.fileDownloads includes "iso"', async ({ page }) => {
    await openPage(page, { fileDownloads: { fileExtensions: ['iso'] } })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.click('#file-download-iso', { modifiers: [metaKey()] })
        await page.click('#file-download', { modifiers: [metaKey()] })
      },
      expectedRequests: [
        { n: 'File Download', p: { url: 'https://awesome.website.com/file.iso' } },
      ],
      rejectRequests: [
        { n: 'File Download', p: { url: 'https://awesome.website.com/file.pdf' } },
      ]
    })
  })

  test('ignores malformed value but enables the feature', async ({ page }) => {
    await openPage(page, { fileDownloads: { fileExtensions: 'iso' } })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.click('#file-download-iso', { modifiers: [metaKey()] })
        await page.click('#file-download', { modifiers: [metaKey()] })
      },
      expectedRequests: [
        { n: 'File Download', p: { url: 'https://awesome.website.com/file.pdf' } },
      ],
      rejectRequests: [
        { n: 'File Download', p: { url: 'https://awesome.website.com/file.iso' } },
      ]
    })
  })
})
