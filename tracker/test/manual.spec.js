const { pageActionAndExpectEventRequests } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('manual extension', () => {
  test('can trigger custom events with and without a custom URL if pageview was sent with the default URL', async ({ page }) => {
    await page.goto('/manual.html')

    await pageActionAndExpectEventRequests(page, () => page.click('#pageview-trigger'), [
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/manual.html`}
    ])
    await pageActionAndExpectEventRequests(page, () => page.click('#custom-event-trigger'), [
      {n: 'CustomEvent', u: `${LOCAL_SERVER_ADDR}/manual.html`}
    ])
    await pageActionAndExpectEventRequests(page, () => page.click('#custom-event-trigger-custom-url'), [
      {n: 'CustomEvent', u: `https://example.com/custom/location`}
    ])
  })

  test('can trigger custom events with and without a custom URL if pageview was sent with a custom URL', async ({ page }) => {
    await page.goto('/manual.html')

    await pageActionAndExpectEventRequests(page, () => page.click('#pageview-trigger-custom-url'), [
      {n: 'pageview', u: `https://example.com/custom/location`}
    ])
    await pageActionAndExpectEventRequests(page, () => page.click('#custom-event-trigger'), [
      {n: 'CustomEvent', u: `${LOCAL_SERVER_ADDR}/manual.html`}
    ])
    await pageActionAndExpectEventRequests(page, () => page.click('#custom-event-trigger-custom-url'), [
      {n: 'CustomEvent', u: `https://example.com/custom/location`}
    ])
  })
})
