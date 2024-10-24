/* eslint-disable playwright/expect-expect */
/* eslint-disable playwright/no-skipped-test */
const { clickPageElementAndExpectEventRequest, mockRequest } = require('./support/test-utils')
const { test } = require('@playwright/test');
const { LOCAL_SERVER_ADDR } = require('./support/server');

test.describe('pageleave extension', () => {
  test('sends a pageleave when navigating to the next page', async ({ page, browserName }) => {
    test.skip(browserName === 'webkit', 'Not testable on Webkit');

    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave.html');
    await pageviewRequestMock;

    await clickPageElementAndExpectEventRequest(page, '#navigate-away', {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`})
  });
});