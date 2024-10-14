const { mockRequest } = require('./support/test-utils')
const { expect, test } = require('@playwright/test');
const { LOCAL_SERVER_ADDR } = require('./support/server');

async function clickPageElementAndExpectEventRequest(page, buttonId, expectedBodyParams) {
  const plausibleRequestMock = mockRequest(page, '/api/event')
  await page.click(buttonId)
  const plausibleRequest = await plausibleRequestMock;

  expect(plausibleRequest.url()).toContain('/api/event')

  const body = plausibleRequest.postDataJSON()

  Object.keys(expectedBodyParams).forEach((key) => {
    expect(body[key]).toEqual(expectedBodyParams[key])
  })
}

test.describe('manual extension', () => {
  test('can trigger custom events with and without a custom URL if pageview was sent with the default URL', async ({ page }) => {
    await page.goto('/manual.html');

    await clickPageElementAndExpectEventRequest(page, '#pageview-trigger', {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/manual.html`})
    await clickPageElementAndExpectEventRequest(page, '#custom-event-trigger', {n: 'CustomEvent', u: `${LOCAL_SERVER_ADDR}/manual.html`})
    await clickPageElementAndExpectEventRequest(page, '#custom-event-trigger-custom-url', {n: 'CustomEvent', u: `https://example.com/custom/location`})
  });

  test('can trigger custom events with and without a custom URL if pageview was sent with a custom URL', async ({ page }) => {
    await page.goto('/manual.html');

    await clickPageElementAndExpectEventRequest(page, '#pageview-trigger-custom-url', {n: 'pageview', u: `https://example.com/custom/location`})
    await clickPageElementAndExpectEventRequest(page, '#custom-event-trigger', {n: 'CustomEvent', u: `${LOCAL_SERVER_ADDR}/manual.html`})
    await clickPageElementAndExpectEventRequest(page, '#custom-event-trigger-custom-url', {n: 'CustomEvent', u: `https://example.com/custom/location`})
  });
});
