const { expectPlausibleInAction } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('manual extension', () => {
  test('can trigger custom events with and without a custom URL if pageview was sent with the default URL', async ({ page }) => {
    await page.goto('/manual.html')

    await expectPlausibleInAction(page, {
      action: () => page.click('#pageview-trigger'),
      expectedRequests: [{n: 'pageview', u: `${LOCAL_SERVER_ADDR}/manual.html`}]
    })
    await expectPlausibleInAction(page, {
      action: () => page.click('#custom-event-trigger'),
      expectedRequests: [{n: 'CustomEvent', u: `${LOCAL_SERVER_ADDR}/manual.html`}]
    })
    await expectPlausibleInAction(page, {
      action: () => page.click('#custom-event-trigger-custom-url'),
      expectedRequests: [{n: 'CustomEvent', u: `https://example.com/custom/location`}]
    })
  })

  test('can trigger custom events with and without a custom URL if pageview was sent with a custom URL', async ({ page }) => {
    await page.goto('/manual.html')

    await expectPlausibleInAction(page, {
      action: () => page.click('#pageview-trigger-custom-url'),
      expectedRequests: [{n: 'pageview', u: `https://example.com/custom/location`}]
    })
    await expectPlausibleInAction(page, {
      action: () => page.click('#custom-event-trigger'),
      expectedRequests: [{n: 'CustomEvent', u: `${LOCAL_SERVER_ADDR}/manual.html`}]
    })
    await expectPlausibleInAction(page, {
      action: () => page.click('#custom-event-trigger-custom-url'),
      expectedRequests: [{n: 'CustomEvent', u: `https://example.com/custom/location`}]
    })
  })
})
