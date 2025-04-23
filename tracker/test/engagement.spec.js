import { expect } from "@playwright/test"
import { expectPlausibleInAction, hideAndShowCurrentTab, focus, blur, blurAndFocusPage, tracker_script_version } from './support/test-utils'
import { test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'

test.describe('engagement events', () => {
  test('sends an engagement event with time measurement when navigating to the next page', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.waitForTimeout(1000)

    const [request] = await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`, v: tracker_script_version}]
    })

    expect(request.e).toBeGreaterThan(1000)
    expect(request.e).toBeLessThan(1500)
  })

  test('sends an event and a pageview on hash-based SPA navigation', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement-hash.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.waitForTimeout(1000)

    const [request] = await expectPlausibleInAction(page, {
      action: () => page.click('#hash-nav'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#some-hash`}
      ]
    })

    expect(request.e).toBeGreaterThan(1000)
    expect(request.e).toBeLessThan(1500)
  })

  test('sends an event and a pageview on history-based SPA navigation', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.waitForTimeout(1000)

    const [request] = await expectPlausibleInAction(page, {
      action: () => page.click('#history-nav'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/another-page`}
      ]
    })

    expect(request.e).toBeGreaterThan(1000)
    expect(request.e).toBeLessThan(1500)
  })

  test('sends engagements when pageviews are triggered manually on a SPA', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement-hash-manual.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.waitForTimeout(1000)

    const [request] = await expectPlausibleInAction(page, {
      action: () => page.click('#about-us-hash-link'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/#home`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/#about-us`}
      ]
    })

    expect(request.e).toBeGreaterThan(1000)
    expect(request.e).toBeLessThan(1500)
  })

  test('sends an event with the manually overridden URL', async ({ page }) => {
    await page.goto('/engagement-manual.html')

    await expectPlausibleInAction(page, {
      action: () => page.click('#pageview-trigger-custom-url'),
      expectedRequests: [{n: 'pageview', u: 'https://example.com/custom/location'}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', u: 'https://example.com/custom/location'}]
    })
  })

  test('does not send an event when pageview was not sent in manual mode', async ({ page }) => {
    await page.goto('/engagement-manual.html')

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      refutedRequests: [{n: 'engagement'}]
    })
  })

  test('script.exclusions.hash.js sends an event only from URLs where a pageview was sent', async ({ page }) => {
    const pageBaseURL = `${LOCAL_SERVER_ADDR}/engagement-hash-exclusions.html`

    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement-hash-exclusions.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    // After the initial pageview is sent, navigate to ignored page ->
    // engagement event is sent from the initial page URL
    await expectPlausibleInAction(page, {
      action: () => page.click('#ignored-hash-link'),
      expectedRequests: [{n: 'engagement', u: pageBaseURL, h: 1}]
    })

    // Navigate from ignored page to a tracked page ->
    // no engagement from the current page, pageview on the next page
    await expectPlausibleInAction(page, {
      action: () => page.click('#hash-link-1'),
      expectedRequests: [{n: 'pageview', u: `${pageBaseURL}#hash1`, h: 1}],
      refutedRequests: [{n: 'engagement'}]
    })

    // Navigate from a tracked page to another tracked page ->
    // engagement with the last page URL, pageview with the new URL
    await expectPlausibleInAction(page, {
      action: () => page.click('#hash-link-2'),
      expectedRequests: [
        {n: 'engagement', u: `${pageBaseURL}#hash1`, h: 1},
        {n: 'pageview', u: `${pageBaseURL}#hash2`, h: 1}
      ]
    })
  })

  test('sends an event with the same props as pageview (manual extension)', async ({ page }) => {
    await page.goto('/engagement-manual.html')

    await expectPlausibleInAction(page, {
      action: () => page.click('#pageview-trigger-custom-props'),
      expectedRequests: [{n: 'pageview', p: {author: 'John'}}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', p: {author: 'John'}}]
    })
  })

  test('sends an event with the same props as pageview (pageview-props extension)', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement-pageview-props.html'),
      expectedRequests: [{n: 'pageview', p: {author: 'John'}}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', p: {author: 'John'}}]
    })
  })

  test('sends an event with the same props as pageview (hash navigation / pageview-props extension)', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement-hash-pageview-props.html'),
      expectedRequests: [{n: 'pageview', p: {}}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#john-post'),
      expectedRequests: [
        {n: 'engagement', p: {}},
        {n: 'pageview', p: {author: 'john'}}
      ]
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#jane-post'),
      expectedRequests: [
        {n: 'engagement', p: {author: 'john'}},
        {n: 'pageview', p: {author: 'jane'}}
      ]
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#home'),
      expectedRequests: [
        {n: 'engagement', p: {author: 'jane'}},
        {n: 'pageview', p: {}}
      ]
    })
  })

  test('sends an event when plausible API is slow and user navigates away before response is received', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement.html'),
      expectedRequests: [{n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.click('#to-pageleave-pageview-props')
        await page.click('#back-button-trigger')
      },
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement-pageview-props.html`, p: {author: 'John'}},
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement-pageview-props.html`, p: {author: 'John'}},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement.html`}
      ],
      responseDelay: 1000
    })
  })

  test('sends engagement events when tab toggles between foreground and background', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    const [request1] = await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page, {delay: 2000}),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })
    expect(request1.e).toBeLessThan(500)

    await page.waitForTimeout(3000)

    const [request2] = await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page, {delay: 2000}),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })

    expect(request2.e).toBeGreaterThan(3000)
    expect(request2.e).toBeLessThan(3500)
  })

  test('does not send engagement events when tab is only open for a short time until over 3000ms has passed', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    const [request1] = await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })
    expect(request1.e).toBeLessThan(500)

    await page.waitForTimeout(500)

    await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page),
      refutedRequests: [{n: 'engagement'}],
      mockRequestTimeout: 100
    })

    await page.waitForTimeout(2500)

    const [request2] = await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page, {delay: 3000}),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })

    // Sum of both visibility times
    expect(request2.e).toBeGreaterThan(3000)
    expect(request2.e).toBeLessThan(3500)
  })

  test('tracks engagement time properly in a SPA', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement-hash.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await page.waitForTimeout(1000)

    const [request] = await expectPlausibleInAction(page, {
      action: () => page.click('#hash-nav'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#some-hash`}
      ]
    })

    expect(request.e).toBeGreaterThan(1000)
    expect(request.e).toBeLessThan(1500)

    const [request2] = await expectPlausibleInAction(page, {
      action: () => page.click('#hash-nav-2'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#some-hash`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#another-hash`}
      ]
    })

    expect(request2.e).toBeLessThan(200)

    await page.waitForTimeout(3000)

    const [request3] = await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#another-hash`}],
    })

    expect(request3.e).toBeGreaterThan(3000)
    expect(request3.e).toBeLessThan(3500)

    await page.waitForTimeout(3000)
    const [request4] = await expectPlausibleInAction(page, {
      action: () => page.click('#hash-nav'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#another-hash`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/engagement-hash.html#some-hash`}
      ]
    })

    expect(request4.e).toBeGreaterThan(3000)
    expect(request4.e).toBeLessThan(3500)
  })

  test('tracks engagement time whilst tab gains and loses focus', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/engagement.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    const [request1] = await expectPlausibleInAction(page, {
      action: () => blur(page),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })
    expect(request1.e).toBeLessThan(500)

    await focus(page)
    await page.waitForTimeout(1000)

    await expectPlausibleInAction(page, {
      action: () => blurAndFocusPage(page, { delay: 3000 }),
      refutedRequests: [{n: 'engagement'}],
      mockRequestTimeout: 100
    })

    await page.waitForTimeout(2500)

    const [request2] = await expectPlausibleInAction(page, {
      action: () => blur(page),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/engagement.html`}],
    })

    expect(request2.e).toBeGreaterThan(3500)
    expect(request2.e).toBeLessThan(4000)
  })
})
