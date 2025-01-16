const { mockRequest, mockManyRequests, metaKey, expectPlausibleInAction } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('file-downloads extension', () => {
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

    const downloadRequestMockList = mockManyRequests(page, downloadURL, 2)
    await page.click('#local-download')

    expect((await downloadRequestMockList).length).toBe(1)
  })
})
