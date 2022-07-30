const { test } = require('./support/harness');
const { mockRequest, expectCustomEvent, isMac } = require('./support/test-utils');
const { expect } = require('@playwright/test');

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
});
