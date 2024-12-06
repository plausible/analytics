/* eslint-disable playwright/no-skipped-test */
const { clickPageElementAndExpectEventRequests, mockRequest } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('pageleave extension', () => {
  test.skip(({browserName}) => browserName === 'webkit', 'Not testable on Webkit')

  test('sends a pageleave when navigating to the next page', async ({ page }) => {
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave.html')
    await pageviewRequestMock

    await clickPageElementAndExpectEventRequests(page, '#navigate-away', [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`}
    ])
  })

  test('sends pageleave and pageview on hash-based SPA navigation', async ({ page }) => {
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave-hash.html')
    await pageviewRequestMock

    await clickPageElementAndExpectEventRequests(page, '#hash-nav', [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html`},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html#some-hash`}
    ])
  })

  test('sends pageleave and pageview on history-based SPA navigation', async ({ page }) => {
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave.html')
    await pageviewRequestMock

    await clickPageElementAndExpectEventRequests(page, '#history-nav', [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/another-page`}
    ])
  })

  test('sends pageleave with the manually overridden URL', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

    await clickPageElementAndExpectEventRequests(page, '#pageview-trigger-custom-url', [
      {n: 'pageview', u: 'https://example.com/custom/location'}
    ])

    await clickPageElementAndExpectEventRequests(page, '#navigate-away', [
      {n: 'pageleave', u: 'https://example.com/custom/location'}
    ])
  })

  test('does not send pageleave when pageview was not sent in manual mode', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

    await clickPageElementAndExpectEventRequests(page, '#navigate-away', [], [
      {n: 'pageleave'}
    ])
  })

  test('script.exclusions.hash.pageleave.js sends pageleave only from URLs where a pageview was sent', async ({ page }) => {
    const pageBaseURL = `${LOCAL_SERVER_ADDR}/pageleave-hash-exclusions.html`
    
    const pageviewRequestMock = mockRequest(page, '/api/event')
    await page.goto('/pageleave-hash-exclusions.html')
    await pageviewRequestMock

    // After the initial pageview is sent, navigate to ignored page ->
    // pageleave event is sent from the initial page URL
    await clickPageElementAndExpectEventRequests(page, '#ignored-hash-link', [
      {n: 'pageleave', u: pageBaseURL, h: 1}
    ])

    // Navigate from ignored page to a tracked page ->
    // no pageleave from the current page, pageview on the next page
    await clickPageElementAndExpectEventRequests(
      page,
      '#hash-link-1',
      [{n: 'pageview', u: `${pageBaseURL}#hash1`, h: 1}],
      [{n: 'pageleave'}]
    )

    // Navigate from a tracked page to another tracked page ->
    // pageleave with the last page URL, pageview with the new URL
    await clickPageElementAndExpectEventRequests(
      page,
      '#hash-link-2',
      [
        {n: 'pageleave', u: `${pageBaseURL}#hash1`, h: 1},
        {n: 'pageview', u: `${pageBaseURL}#hash2`, h: 1}
      ],
    )
  })
})