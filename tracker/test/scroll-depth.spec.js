import { expectPlausibleInAction, hideCurrentTab, hideAndShowCurrentTab } from './support/test-utils'
import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'

test.describe('scroll depth (engagement events)', () => {
  test('sends scroll_depth in the pageleave payload when navigating to the next page', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.evaluate(() => window.scrollBy(0, 300))
    await page.evaluate(() => window.scrollBy(0, 0))

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth.html`, sd: 20}]
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
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html`, sd: 100},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#about`}
      ]
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#home-link'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#about`, sd: 34},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/scroll-depth-hash.html#home`}
      ]
    })
  })

  test('document height gets reevaluated after window load', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-slow-window-load.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    // Wait for the image to be loaded
    await page.waitForFunction(() => {
      return document.getElementById('slow-image').complete
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{
        n: 'engagement',
        u: `${LOCAL_SERVER_ADDR}/scroll-depth-slow-window-load.html`, sd: 24
      }]
    })
  })

  test('dynamically loaded content affects documentHeight', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-dynamic-content-load.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    // The link appears dynamically after 500ms.
    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth-dynamic-content-load.html`, sd: 14}]
    })
  })

  test('document height gets reevaluated on scroll', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth-content-onscroll.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    // During the first 3 seconds, the script periodically updates document height
    // to account for dynamically loaded content. Since we want to test document
    // height also getting updated on scroll, we need to just wait for 3 seconds.
    await page.waitForTimeout(3100)

    // scroll to the bottom of the page
    await page.evaluate(() => window.scrollBy(0, document.body.scrollHeight))

    // Wait until documentHeight gets increased by the fixture JS
    await expect(page.getByText('Navigate away')).toBeVisible()

    await page.evaluate(() => window.scrollBy(0, 1000))

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth-content-onscroll.html`, sd: 80}]
    })
  })

  test('sends scroll depth when minimizing the tab', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/scroll-depth.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.evaluate(() => window.scrollBy(0, 300))
    await page.waitForTimeout(100) // Wait for the scroll event to be processed

    await expectPlausibleInAction(page, {
      action: () => hideCurrentTab(page),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth.html`, sd: 20}],
    })
  })

  test('re-sends engagement events only when user has scrolled in-between', async ({ page, browserName }) => {
    test.skip(browserName === 'webkit', 'flaky')

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto('/scroll-depth.html')
        await hideAndShowCurrentTab(page)
      },
      expectedRequests: [
        {n: 'pageview'},
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth.html`, sd: 14}
      ],
    })

    await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page),
      expectedRequests: [],
      refutedRequests: [{n: 'engagement'}]
    })

    await page.evaluate(() => window.scrollBy(0, 300))

    await expectPlausibleInAction(page, {
      action: () => hideCurrentTab(page),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/scroll-depth.html`, sd: 20}],
    })
  })


  test('gets correct scroll depth when script has no async', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto('/no-async.html')
        await hideAndShowCurrentTab(page)
      },
      expectedRequests: [
        {n: 'pageview'},
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/no-async.html`, sd: 100}
      ],
    })

    await page.waitForTimeout(1000)
  })
})
