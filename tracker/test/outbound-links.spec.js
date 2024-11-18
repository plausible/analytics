const { mockRequest, expectCustomEvent, metaKey } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')

test.describe('outbound-links extension', () => {

  test('sends event and does not navigate when link opens in new tab', async ({ page }) => {
    await page.goto('/outbound-link.html')
    const outboundURL = await page.locator('#link').getAttribute('href')

    const plausibleRequestMock = mockRequest(page, '/api/event')
    const navigationRequestMock = mockRequest(page, outboundURL)

    await page.click('#link', { modifiers: [metaKey()] })

    expectCustomEvent(await plausibleRequestMock, 'Outbound Link: Click', { url: outboundURL })
    expect(await navigationRequestMock, "should not have made navigation request").toBeNull()
  })

  test('sends event and navigates to target when link child is clicked', async ({ page }) => {
    await page.goto('/outbound-link.html')
    const outboundURL = await page.locator('#link').getAttribute('href')

    const plausibleRequestMock = mockRequest(page, '/api/event')
    const navigationRequestMock = mockRequest(page, outboundURL)

    await page.click('#link-child')

    const navigationRequest = await navigationRequestMock
    expectCustomEvent(await plausibleRequestMock, 'Outbound Link: Click', { url: outboundURL })
    expect(navigationRequest.url()).toContain(outboundURL)
  })

  test('sends event and does not navigate if default externally prevented', async ({ page }) => {
    await page.goto('/outbound-link.html')
    const outboundURL = await page.locator('#link-default-prevented').getAttribute('href')

    const plausibleRequestMock = mockRequest(page, '/api/event')
    const navigationRequestMock = mockRequest(page, outboundURL)

    await page.click('#link-default-prevented')

    expectCustomEvent(await plausibleRequestMock, 'Outbound Link: Click', { url: outboundURL })
    expect(await navigationRequestMock, "should not have made navigation request").toBeNull()
  })
})
