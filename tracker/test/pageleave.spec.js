/* eslint-disable playwright/no-skipped-test */
const { pageActionAndExpectEventRequests } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('pageleave extension', () => {
  test.skip(({browserName}) => browserName === 'webkit', 'Not testable on Webkit')

  test('sends a pageleave when navigating to the next page', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/pageleave.html'), [
      {n: 'pageview'}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`}
    ])
  })

  test('sends pageleave and pageview on hash-based SPA navigation', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/pageleave-hash.html'), [
      {n: 'pageview'}
    ])
    
    await pageActionAndExpectEventRequests(page, () => page.click('#hash-nav'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html`},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html#some-hash`}
    ])
  })

  test('sends pageleave and pageview on history-based SPA navigation', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/pageleave.html'), [
      {n: 'pageview'}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#history-nav'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/pageleave.html`},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/another-page`}
    ])
  })

  test('sends pageleave with the manually overridden URL', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

    await pageActionAndExpectEventRequests(page, () => page.click('#pageview-trigger-custom-url'), [
      {n: 'pageview', u: 'https://example.com/custom/location'}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', u: 'https://example.com/custom/location'}
    ])
  })

  test('does not send pageleave when pageview was not sent in manual mode', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [], [
      {n: 'pageleave'}
    ])
  })

  test('script.exclusions.hash.pageleave.js sends pageleave only from URLs where a pageview was sent', async ({ page }) => {
    const pageBaseURL = `${LOCAL_SERVER_ADDR}/pageleave-hash-exclusions.html`

    await pageActionAndExpectEventRequests(page, () => page.goto('/pageleave-hash-exclusions.html'), [
      {n: 'pageview'}
    ])    

    // After the initial pageview is sent, navigate to ignored page ->
    // pageleave event is sent from the initial page URL
    await pageActionAndExpectEventRequests(page, () => page.click('#ignored-hash-link'), [
      {n: 'pageleave', u: pageBaseURL, h: 1}
    ])

    // Navigate from ignored page to a tracked page ->
    // no pageleave from the current page, pageview on the next page
    await pageActionAndExpectEventRequests(
      page,
      () => page.click('#hash-link-1'),
      [{n: 'pageview', u: `${pageBaseURL}#hash1`, h: 1}],
      [{n: 'pageleave'}]
    )

    // Navigate from a tracked page to another tracked page ->
    // pageleave with the last page URL, pageview with the new URL
    await pageActionAndExpectEventRequests(
      page,
      () => page.click('#hash-link-2'),
      [
        {n: 'pageleave', u: `${pageBaseURL}#hash1`, h: 1},
        {n: 'pageview', u: `${pageBaseURL}#hash2`, h: 1}
      ],
    )
  })

  test('sends pageleave with the same props as pageview (manual extension)', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

    await pageActionAndExpectEventRequests(page, () => page.click('#pageview-trigger-custom-props'), [
      {n: 'pageview', p: {author: 'John'}}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', p: {author: 'John'}}
    ])
  })

  test('sends pageleave with the same props as pageview (pageview-props extension)', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/pageleave-pageview-props.html'), [
      {n: 'pageview', p: {author: 'John'}}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', p: {author: 'John'}}
    ])
  })

  test('sends pageleave with the same props as pageview (hash navigation / pageview-props extension)', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/pageleave-hash-pageview-props.html'), [
      {n: 'pageview', p: {}}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#john-post'), [
      {n: 'pageleave', p: {}},
      {n: 'pageview', p: {author: 'john'}}
    ])

    // Wait 600ms before navigating again because pageleave events are throttled to 500ms.
    await page.waitForTimeout(600)

    await pageActionAndExpectEventRequests(page, () => page.click('#jane-post'), [
      {n: 'pageleave', p: {author: 'john'}},
      {n: 'pageview', p: {author: 'jane'}}
    ])

    await page.waitForTimeout(600)

    await pageActionAndExpectEventRequests(page, () => page.click('#home'), [
      {n: 'pageleave', p: {author: 'jane'}},
      {n: 'pageview', p: {}}
    ])
  })
})