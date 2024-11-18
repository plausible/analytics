const { mockRequest, expectCustomEvent } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')

test.describe('with revenue script extension', () => {
  test('sends revenue currency and amount in manual mode', async ({ page }) => {
    const plausibleRequestMock = mockRequest(page, '/api/event')
    await page.goto('/revenue.html')
    await page.click('#manual-purchase')

    const plausibleRequest = await plausibleRequestMock
    expect(plausibleRequest.postDataJSON()["$"]).toEqual({amount: 15.99, currency: "USD"})
  })

  test('sends revenue currency and amount with tagged class name', async ({ page }) => {
    const plausibleRequestMock = mockRequest(page, '/api/event')
    await page.goto('/revenue.html')
    await page.click('#tagged-purchase')

    const plausibleRequest = await plausibleRequestMock
    expect(plausibleRequest.postDataJSON()["$"]).toEqual({amount: "13.32", currency: "EUR"})
  })
})
