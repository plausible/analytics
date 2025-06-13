import { mockRequest, expectPlausibleInAction } from './support/test-utils'
import { expect, test } from '@playwright/test'

test.describe('outbound-links extension', () => {
  test('sends event and does not navigate when link opens in new tab', async ({ page }) => {
    await page.goto('/outbound-link.html')
    const outboundURL = await page.locator('#link').getAttribute('href')

    const navigationRequestMock = mockRequest(page, outboundURL)

    await expectPlausibleInAction(page, {
      action: () => page.click('#link', { modifiers: ['ControlOrMeta'] }),
      expectedRequests: [{n: 'Outbound Link: Click', p: { url: outboundURL }}]
    })

    expect(await navigationRequestMock, "should not have made navigation request").toBeNull()
  })

  test('sends event and navigates to target when link child is clicked', async ({ page }) => {
    await page.goto('/outbound-link.html')
    const outboundURL = await page.locator('#link').getAttribute('href')

    const navigationRequestMock = mockRequest(page, outboundURL)

    await expectPlausibleInAction(page, {
      action: () => page.click('#link-child'),
      expectedRequests: [{n: 'Outbound Link: Click', p: { url: outboundURL }}]
    })

    const navigationRequest = await navigationRequestMock
    expect(navigationRequest.url()).toContain(outboundURL)
  })

  test('sends event and does not navigate if default externally prevented', async ({ page }) => {
    await page.goto('/outbound-link.html')
    const outboundURL = await page.locator('#link-default-prevented').getAttribute('href')

    const navigationRequestMock = mockRequest(page, outboundURL)

    await expectPlausibleInAction(page, {
      action: () => page.click('#link-default-prevented'),
      expectedRequests: [{n: 'Outbound Link: Click', p: { url: outboundURL }}]
    })

    expect(await navigationRequestMock, "should not have made navigation request").toBeNull()
  })
})
