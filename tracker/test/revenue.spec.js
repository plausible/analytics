const { mockRequest, expectCustomEvent } = require('./support/test-utils');
const { expect, test } = require('@playwright/test');

test.describe('with revenue script extension', () => {
  test('sends revenue currency and amount', async ({ page }) => {
    const plausibleRequestMock = mockRequest(page, '/api/event')
    await page.goto('/revenue.html');
    await page.click('#purchase')

    const plausibleRequest = await plausibleRequestMock
    expect(plausibleRequest.postDataJSON()["$"]).toEqual({amount: 15.99, currency: "USD"})
  });
});
