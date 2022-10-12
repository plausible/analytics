const { test } = require('./support/harness');
const { mockRequest, expectCustomEvent, isMac, mockManyRequests } = require('./support/test-utils');
const { expect } = require('@playwright/test');
const { LOCAL_SERVER_ADDR } = require('./support/server');


test.describe('file-downloads extension', () => {
  test('sends event and does not start download when link opens in new tab', async ({ page }, workerInfo) => {
    await page.goto('/file-download.html')
    const downloadURL = await page.locator('#link').getAttribute('href')

    const plausibleRequestMock = mockRequest(page, '/api/event')
    const downloadRequestMock = mockRequest(page, downloadURL)
    await page.click('#link', { modifiers: [isMac(workerInfo) ? 'Meta' : 'Control'] })

    expectCustomEvent(await plausibleRequestMock, 'File Download', { url: downloadURL })
    expect(await downloadRequestMock, "should not make download request").toBeNull()
  });

  test('sends event and starts download when link child is clicked', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = await page.locator('#link').getAttribute('href')

    const plausibleRequestMock = mockRequest(page, '/api/event')
    const downloadRequestMock = mockRequest(page, downloadURL)
    await page.click('#link-child')

    expectCustomEvent(await plausibleRequestMock, 'File Download', { url: downloadURL })
    expect((await downloadRequestMock).url()).toContain(downloadURL)
  });

  test('sends File Download event with query-stripped url property', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = await page.locator('#link-query').getAttribute('href')

    const plausibleRequestMock = mockRequest(page, '/api/event')
    await page.click('#link-query')

    const expectedURL = downloadURL.split("?")[0]
    expectCustomEvent(await plausibleRequestMock, 'File Download', { url: expectedURL })
  });

  test('starts download only once', async ({ page }) => {
    await page.goto('/file-download.html')
    const downloadURL = LOCAL_SERVER_ADDR + '/' + await page.locator('#local-download').getAttribute('href')

    const downloadRequestMockList = mockManyRequests(page, downloadURL, 2)
    await page.click('#local-download')

    expect((await downloadRequestMockList).length).toBe(1)
  });
});
