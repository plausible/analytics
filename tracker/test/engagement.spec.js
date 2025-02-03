const { expectPlausibleInAction, engagementCooldown } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('engagement events', () => {
  test('sends a pageleave when navigating to the next page', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/pageleave.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', u: `${LOCAL_SERVER_ADDR}/pageleave.html`}]
    })
  })

  test('sends an event and a pageview on hash-based SPA navigation', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/pageleave-hash.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#hash-nav'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave-hash.html#some-hash`}
      ]
    })
  })

  test('sends an event and a pageview on history-based SPA navigation', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/pageleave.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#history-nav'),
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/pageleave.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/another-page`}
      ]
    })
  })

  test('sends an event with the manually overridden URL', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

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
    await page.goto('/pageleave-manual.html')

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      refutedRequests: [{n: 'engagement'}]
    })
  })

  test('script.exclusions.hash.pageleave.js sends an event only from URLs where a pageview was sent', async ({ page }) => {
    const pageBaseURL = `${LOCAL_SERVER_ADDR}/pageleave-hash-exclusions.html`

    await expectPlausibleInAction(page, {
      action: () => page.goto('/pageleave-hash-exclusions.html'),
      expectedRequests: [{n: 'pageview'}],
    })

    // After the initial pageview is sent, navigate to ignored page ->
    // pageleave event is sent from the initial page URL
    await expectPlausibleInAction(page, {
      action: () => page.click('#ignored-hash-link'),
      expectedRequests: [{n: 'engagement', u: pageBaseURL, h: 1}]
    })

    await engagementCooldown(page)

    // Navigate from ignored page to a tracked page ->
    // no pageleave from the current page, pageview on the next page
    await expectPlausibleInAction(page, {
      action: () => page.click('#hash-link-1'),
      expectedRequests: [{n: 'pageview', u: `${pageBaseURL}#hash1`, h: 1}],
      refutedRequests: [{n: 'engagement'}]
    })

    await engagementCooldown(page)

    // Navigate from a tracked page to another tracked page ->
    // pageleave with the last page URL, pageview with the new URL
    await expectPlausibleInAction(page, {
      action: () => page.click('#hash-link-2'),
      expectedRequests: [
        {n: 'engagement', u: `${pageBaseURL}#hash1`, h: 1},
        {n: 'pageview', u: `${pageBaseURL}#hash2`, h: 1}
      ]
    })
  })

  test('sends an event with the same props as pageview (manual extension)', async ({ page }) => {
    await page.goto('/pageleave-manual.html')

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
      action: () => page.goto('/pageleave-pageview-props.html'),
      expectedRequests: [{n: 'pageview', p: {author: 'John'}}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#navigate-away'),
      expectedRequests: [{n: 'engagement', p: {author: 'John'}}]
    })
  })

  test('sends an event with the same props as pageview (hash navigation / pageview-props extension)', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => page.goto('/pageleave-hash-pageview-props.html'),
      expectedRequests: [{n: 'pageview', p: {}}],
    })

    await expectPlausibleInAction(page, {
      action: () => page.click('#john-post'),
      expectedRequests: [
        {n: 'engagement', p: {}},
        {n: 'pageview', p: {author: 'john'}}
      ]
    })

    await engagementCooldown(page)

    await expectPlausibleInAction(page, {
      action: () => page.click('#jane-post'),
      expectedRequests: [
        {n: 'engagement', p: {author: 'john'}},
        {n: 'pageview', p: {author: 'jane'}}
      ]
    })

    await engagementCooldown(page)

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
      action: () => page.goto('/pageleave.html'),
      expectedRequests: [{n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave.html`}],
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.click('#to-pageleave-pageview-props')
        await page.click('#back-button-trigger')
      },
      expectedRequests: [
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/pageleave.html`},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave-pageview-props.html`, p: {author: 'John'}},
        {n: 'engagement', u: `${LOCAL_SERVER_ADDR}/pageleave-pageview-props.html`, p: {author: 'John'}},
        {n: 'pageview', u: `${LOCAL_SERVER_ADDR}/pageleave.html`}
      ],
      responseDelay: 1000
    })
  })

})
