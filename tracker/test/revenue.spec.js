import { expectPlausibleInAction } from './support/test-utils'
import { test } from '@playwright/test'

test.describe('with revenue script extension', () => {
  test('sends revenue currency and amount in manual mode', async ({ page }) => {
    await page.goto('/revenue.html')

    await expectPlausibleInAction(page, {
      action: () => page.locator('#manual-purchase').click(),
      expectedRequests: [
        { n: 'Purchase', $: { amount: 15.99, currency: 'USD' } }
      ]
    })
  })

  test('sends revenue currency and amount with tagged class name', async ({
    page
  }) => {
    await page.goto('/revenue.html')

    await expectPlausibleInAction(page, {
      action: () => page.locator('#tagged-purchase').click(),
      expectedRequests: [
        { n: 'Purchase', $: { amount: '13.32', currency: 'EUR' } }
      ]
    })
  })
})
