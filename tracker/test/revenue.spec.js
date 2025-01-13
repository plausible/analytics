const { pageActionAndExpectEventRequests } = require('./support/test-utils')
const { test } = require('@playwright/test')

test.describe('with revenue script extension', () => {
  test('sends revenue currency and amount in manual mode', async ({ page }) => {
    await page.goto('/revenue.html')
    
    await pageActionAndExpectEventRequests(page, () => page.click('#manual-purchase'), [
      {n: "Purchase", $: {amount: 15.99, currency: "USD"}}
    ])
  })

  test('sends revenue currency and amount with tagged class name', async ({ page }) => {
    await page.goto('/revenue.html')
    
    await pageActionAndExpectEventRequests(page, () => page.click('#tagged-purchase'), [
      {n: "Purchase", $: {amount: "13.32", currency: "EUR"}}
    ])
  })
})
