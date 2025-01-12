/* eslint-disable playwright/no-skipped-test */
const { pageActionAndExpectEventRequests, pageleaveCooldown } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('scroll depth', () => {
  test.skip(({browserName}) => browserName === 'webkit', 'Not testable on Webkit')

  test('sends scroll_depth in the pageleave payload when navigating to the next page', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/scroll-depth.html'), [
      {n: 'pageview'}
    ])

    await page.evaluate(() => window.scrollBy(0, 300))
    await page.evaluate(() => window.scrollBy(0, 0))

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth.html`, sd: 20}
    ])
  })

  test('sends scroll depth on hash navigation', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/scroll-depth-hash.html'), [
      {n: 'pageview'}
    ])

    await pageActionAndExpectEventRequests(page, () => page.click('#about-link'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html`, sd: 100},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#about`}
    ])

    await pageleaveCooldown(page)

    await pageActionAndExpectEventRequests(page, () => page.click('#home-link'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#about`, sd: 34},
      {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#home`}
    ])
  })

  test('document height gets reevaluated after window load', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/scroll-depth-slow-window-load.html'), [
      {n: 'pageview'}
    ])

    // Wait for the image to be loaded
    await page.waitForFunction(() => {
      return document.getElementById('slow-image').complete
    })

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-slow-window-load.html`, sd: 24}
    ])
  })

  test('dynamically loaded content affects documentHeight', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/scroll-depth-dynamic-content-load.html'), [
      {n: 'pageview'}
    ])
    

    // The link appears dynamically after 500ms.
    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-dynamic-content-load.html`, sd: 14}
    ])
  })

  test('document height gets reevaluated on scroll', async ({ page }) => {
    await pageActionAndExpectEventRequests(page, () => page.goto('/scroll-depth-content-onscroll.html'), [
      {n: 'pageview'}
    ])

    // During the first 3 seconds, the script periodically updates document height
    // to account for dynamically loaded content. Since we want to test document
    // height also getting updated on scroll, we need to just wait for 3 seconds.
    await page.waitForTimeout(3100)

    // scroll to the bottom of the page
    await page.evaluate(() => window.scrollBy(0, document.body.scrollHeight))
    
    // Wait until documentHeight gets increased by the fixture JS
    await page.waitForSelector('#more-content')

    await page.evaluate(() => window.scrollBy(0, 1000))

    await pageActionAndExpectEventRequests(page, () => page.click('#navigate-away'), [
      {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-content-onscroll.html`, sd: 80}
    ])
  })
})