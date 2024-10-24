/* eslint-disable playwright/expect-expect */
/* eslint-disable playwright/no-skipped-test */
const { clickPageElementAndExpectEventRequests, mockRequest } = require('./support/test-utils')
const { test } = require('@playwright/test');
const { LOCAL_SERVER_ADDR } = require('./support/server');

test.describe('pageleave extension', () => {
  test.skip(({browserName}) => browserName === 'webkit', 'Not testable on Webkit');

  test('sends a pageleave when navigating to the next page', async ({ page }) => {
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave.html');
    await pageviewRequestMock;

    await clickPageElementAndExpectEventRequests(page, '#navigate-away', [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`}
    ])
  });

  test('sends pageleave and pageview on hash-based SPA navigation', async ({ page }) => {
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave-hash.html');
    await pageviewRequestMock;

    await clickPageElementAndExpectEventRequests(page, '#hash-nav', [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html`},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html#some-hash`}
    ])
  });

  test('sends pageleave and pageview on history-based SPA navigation', async ({ page }) => {
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave.html');
    await pageviewRequestMock;

    await clickPageElementAndExpectEventRequests(page, '#history-nav', [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/another-page`}
    ])
  });
});