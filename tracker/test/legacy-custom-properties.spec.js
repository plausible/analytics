import { expectPlausibleInAction, isPageviewEvent } from './support/test-utils'
import { test } from '@playwright/test'

test.describe('legacy custom properties support', () => {
  test('sends custom properties via dom attributes', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto('/legacy-pageview-properties.html')
        await page.locator('#custom-event-button').click()
      },
      expectedRequests: [
        { n: 'pageview', p: { author: 'John', foo: 'bar' } },
        { n: 'Custom event', p: { author: 'Karl', foo: 'bar' } }
      ]
    })
  })

  test('sends custom properties via `props`', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto('/legacy-custom-properties.html')
        await page.locator('#custom-props-button').click()
      },
      expectedRequests: [{ n: 'Props event', p: { type: 'props' } }],
      shouldIgnoreRequest: isPageviewEvent
    })
  })

  test('sends custom properties via `meta`', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto('/legacy-custom-properties.html')
        await page.locator('#custom-meta-button').click()
      },
      expectedRequests: [{ n: 'Meta event', m: '{"type":"meta"}' }],
      shouldIgnoreRequest: isPageviewEvent
    })
  })
})
