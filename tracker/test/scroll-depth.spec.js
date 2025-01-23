/* eslint-disable playwright/no-skipped-test */
const { pageleaveCooldown, expectPlausibleInAction } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('scroll depth', () => {
  test.skip(({browserName}) => browserName === 'webkit', 'Not testable on Webkit')

  test('sends scroll_depth in the pageleave payload when navigating to the next page', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth.html'),
      expectedRequests: [{n: 'pageview'}]
    })

    await page.evaluate(() => window.scrollBy(0, 300))
    await page.evaluate(() => window.scrollBy(0, 0))

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth.html`, sd: 20}]
    })
  })

  test('sends scroll depth on hash navigation', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-hash.html'),
      expectedRequests: [{n: 'pageview'}]
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#about-link'),
      expectedRequests: [
        {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html`, sd: 100},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#about`}
      ]
    })

    await pageleaveCooldown(page)

    await expectPlausibleInAction(page, {
      action: () => page.click('#home-link'),
      expectedRequests: [
        {n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#about`, sd: 34},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#home`}
      ]
    })
  })

  test('document height gets reevaluated after window load', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-slow-window-load.html'),
      expectedRequests: [{n: 'pageview'}]
    })

    // Wait for the image to be loaded
    await page.waitForFunction(() => {
      return document.getElementById('slow-image').complete
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-slow-window-load.html`, sd: 24}]
    })
  })

  test('dynamically loaded content affects documentHeight', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-dynamic-content-load.html'),
      expectedRequests: [{n: 'pageview'}]
    })
    
    // The link appears dynamically after 500ms.
    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-dynamic-content-load.html`, sd: 14}]
    })
  })

  test('document height gets reevaluated on scroll', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-content-onscroll.html'),
      expectedRequests: [{n: 'pageview'}]
    })

    // During the first 3 seconds, the script periodically updates document height
    // to account for dynamically loaded content. Since we want to test document
    // height also getting updated on scroll, we need to just wait for 3 seconds.
    await page.waitForTimeout(3100)

    // scroll to the bottom of the page
    await page.evaluate(() => window.scrollBy(0, document.body.scrollHeight))
    
    // Wait until documentHeight gets increased by the fixture JS
    await page.waitForSelector('#more-content')

    await page.evaluate(() => window.scrollBy(0, 1000))

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'pageleave', u: `${LOCAL_SERVER_ADDR}/scroll-depth-content-onscroll.html`, sd: 80}]
    })
  })
})