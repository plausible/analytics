import {
  expectPlausibleInAction,
  isPageviewEvent,
  isEngagementEvent,
  switchByMode
} from './support/test-utils'
import { expect, test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import { initializePageDynamically } from './support/initialize-page-dynamically'
import { ScriptConfig } from './support/types'
import { mockManyRequests } from './support/mock-many-requests'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

test.beforeEach(async ({ page }) => {
  await page
    .context()
    .route(new RegExp('(http|https)://example\\.com.*'), async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'text/html',
        body: '<!DOCTYPE html><html><head><title>mocked page</title></head><body>mocked page</body></html>'
      })
    })
})

for (const mode of ['legacy', 'web']) {
  test.describe(`tagged events feature legacy/v2 parity (${mode})`, () => {
    test('tracks link click and child of link click when link is tagged (using plausible-event-... double dash syntax)', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `
        <a class="plausible-event-name--Payment+Complete should ignore-this plausible-event-amount--100 plausible-event-method--Credit+Card" href="https://example.com/payment?secret=foo">
            <h1>✅</h1>
        </a>`
      })
      await page.goto(url)

      const expectedRequests = [
        {
          n: 'Payment Complete',
          p: {
            amount: '100',
            method: 'Credit Card',
            url: 'https://example.com/payment?secret=foo'
          }
        }
      ]
      await expectPlausibleInAction(page, {
        action: () => page.click('a', { modifiers: ['ControlOrMeta'] }), // open in new tab
        expectedRequests,
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expectPlausibleInAction(page, {
        action: () => page.click('h1'),
        expectedRequests,
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks link press when its parent div is tagged (using plausible-event-... equals syntax)', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<div class="plausible-event-name=Reset+Password plausible-event-foo=bar">
          <a href="https://example.com/reset?verification=123">Reset password</a>
        </div>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.press('a', 'Enter'),
        expectedRequests: [
          {
            n: 'Reset Password',
            p: {
              foo: 'bar',
              url: 'https://example.com/reset?verification=123'
            }
          }
        ],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks tagged form submitted using Enter in text input', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `
        <form class="plausible-event-name=Signup plausible-event-type=Newsletter" action="https://example.com/register" method="post">
          <h2>Newsletter Signup</h2>
          <label for="email">Email:</label>
          <input type="email" />
          <input type="submit" value="Submit" />
        </form>`
      })
      await page.goto(url)

      // if the form is tagged, clicks within the form should not trigger events
      await expectPlausibleInAction(page, {
        action: async () => {
          await page.click('form')
          await page.click('h2')
          await page.click('label', { button: 'right' })
        },
        expectedRequests: [],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.fill('input[type="email"]', 'anything@example.com')
          await page.press('input[type="email"]', 'Enter')
        },
        expectedRequests: [
          {
            n: 'Signup',
            p: { type: 'Newsletter' }
          }
        ],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks only submit in a form when its parent is tagged', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `
        <div class="plausible-event-name=Form+Submit">
          <form action="https://example.com/register" method="post">
            <input type="text"/>
            <input type="submit" value="Submit" />
          </form>
        </div>`
      })
      await page.goto(url)

      // if the form parent is tagged, clicks within the form should not trigger events
      await expectPlausibleInAction(page, {
        action: async () => {
          await page.click('form')
          await page.click('input[type="text"]')
        },
        expectedRequests: [],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expectPlausibleInAction(page, {
        action: () => page.click('input[type="submit"]'),
        expectedRequests: [
          {
            n: 'Form Submit'
          }
        ],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks tagged span click and clicks on any child', async ({ page }, {
      testId
    }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<span class="plausible-event-name=Custom+Event plausible-event-foo=bar"><strong>any</strong>text</span>`
      })
      await page.goto(url)

      const expectedRequests = [
        {
          n: 'Custom Event',
          p: { foo: 'bar' }
        }
      ]

      await expectPlausibleInAction(page, {
        action: () => page.click('span'),
        expectedRequests,
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })

      await expectPlausibleInAction(page, {
        action: () => page.click('strong'),
        expectedRequests,
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks tagged button click', async ({ page }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<button class="plausible-event-name=Custom+Event plausible-event-foo=bar">✅</button>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('button'),
        expectedRequests: [
          {
            n: 'Custom Event',
            p: { foo: 'bar' }
          }
        ],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks dynamically added tagged button', async ({ page }, {
      testId
    }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: ''
      })
      await page.goto(url)

      await page.evaluate(() => {
        return new Promise((resolve) => {
          let taggedElement
          while (!taggedElement) {
            if ((window as any).plausible?.l !== true) {
              continue
            } else {
              taggedElement = document.createElement('button')
              taggedElement.classList.add('plausible-event-name=Custom+Event')
              taggedElement.innerHTML += 'Dynamic'
              document.body.appendChild(taggedElement)
            }
          }
          resolve(true)
        })
      })

      await expectPlausibleInAction(page, {
        action: () => page.click('button'),
        expectedRequests: [
          {
            n: 'Custom Event'
          }
        ],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks tagged links without delaying navigation, relying on fetch options.keepalive to deliver tracking events', async ({
      page
    }, { testId }) => {
      const eventsApiMock = await mockManyRequests({
        page,
        path: '**/api/event',
        countOfRequestsToAwait: 1,
        responseDelay: 500
      })
      const targetPage = await initializePageDynamically(page, {
        testId,
        scriptConfig: '',
        bodyContent: `<h1>Subscription successful</h1>`,
        path: '/target'
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG, autoCapturePageviews: false },
            legacy:
              '<script defer src="/tracker/js/plausible.local.manual.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<a class="plausible-event-name=Subscribe" href="${targetPage.url}">Click to subscribe</a>`
      })
      await page.goto(url)
      const navigationPromise = page.waitForRequest(targetPage.url, {
        timeout: 2000
      })
      await page.click('a')
      const [{ trackingRequestList, trackingResponseTime }, navigationTime] =
        await Promise.all([
          eventsApiMock.getRequestList().then((requestList) => ({
            trackingRequestList: requestList,
            trackingResponseTime: Date.now()
          })),
          navigationPromise.then(Date.now)
        ])
      await expect(page.getByText('Subscription successful')).toBeVisible()
      expect(navigationTime).toBeLessThanOrEqual(trackingResponseTime)
      expect(trackingRequestList).toEqual([
        expect.objectContaining({
          n: 'Subscribe',
          p: {
            url: `${LOCAL_SERVER_ADDR}${targetPage.url}`
          }
        })
      ])
    })

    test('does not track button without plausible-event-name class', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<button class="anything">✅</button>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('button'),
        refutedRequests: [{ n: expect.any(String) }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('does not track click on span with class="plausible-event-name="', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: { ...DEFAULT_CONFIG },
            legacy:
              '<script defer src="/tracker/js/plausible.local.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<span class="plausible-event-name=">anything</span>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('span'),
        refutedRequests: [{ n: expect.any(String) }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })
  })
}

test.describe('tagged events feature when using legacy .compat extension', () => {
  test('tracking delays navigation until the tracking request has finished', async ({
    page
  }, { testId }) => {
    const eventsApiMock = await mockManyRequests({
      page,
      path: '**/api/event',
      countOfRequestsToAwait: 1,
      responseDelay: 1000
    })
    const targetPage = await initializePageDynamically(page, {
      testId,
      scriptConfig: '',
      bodyContent: `<h1>Subscription successful</h1>`,
      path: '/target'
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.tagged-events.js"></script>',
      bodyContent: `<a class="plausible-event-name=Subscribe" href="${targetPage.url}">Click to subscribe</a>`
    })
    await page.goto(url)
    const navigationPromise = page.waitForRequest(targetPage.url, {
      timeout: 2000
    })
    const trackingPromise = page.waitForResponse('**/api/event', {
      timeout: 2000
    })
    await page.click('a')
    const [trackingResponseTime, navigationTime] = await Promise.all([
      trackingPromise.then(Date.now),
      navigationPromise.then(Date.now)
    ])
    await expect(page.getByText('Subscription successful')).toBeVisible()
    expect(trackingResponseTime).toBeLessThan(navigationTime)
    await expect(eventsApiMock.getRequestList()).resolves.toEqual([
      expect.objectContaining({
        n: 'Subscribe',
        p: {
          url: `${LOCAL_SERVER_ADDR}${targetPage.url}`
        }
      })
    ])
  })

  test('if the tracking requests delays navigation for more than 5s, it navigates anyway, without waiting for the request to resolve', async ({
    page
  }, { testId }) => {
    test.setTimeout(20000)
    await mockManyRequests({
      page,
      path: '**/api/event',
      countOfRequestsToAwait: 1,
      responseDelay: 6000
    })
    const targetPage = await initializePageDynamically(page, {
      testId,
      scriptConfig: '',
      bodyContent: `<h1>Subscription successful</h1>`,
      path: '/target'
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.tagged-events.js"></script>',
      bodyContent: `<a class="plausible-event-name=Subscribe" href="${targetPage.url}">Click to subscribe</a>`
    })
    await page.goto(url)
    const navigationPromise = page.waitForRequest(targetPage.url, {
      timeout: 7000
    })
    const trackingPromise = page.waitForResponse('**/api/event', {
      timeout: 7000
    })
    await page.click('a')
    const [trackingResponseTime, navigationTime] = await Promise.all([
      trackingPromise.then(Date.now).catch(Date.now),
      navigationPromise.then(Date.now)
    ])
    await expect(page.getByText('Subscription successful')).toBeVisible()
    expect(navigationTime).toBeLessThan(trackingResponseTime)
  })

  test('does not track link without plausible-event-name class, the link still navigates as it should', async ({
    page
  }, { testId }) => {
    const targetPage = await initializePageDynamically(page, {
      testId,
      scriptConfig: '',
      bodyContent: `<h1>Subscription successful</h1>`,
      path: '/target'
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.tagged-events.js"></script>',
      bodyContent: `<a class="plausible-event-key=value" href="${targetPage.url}">Click to subscribe</a>`
    })
    await page.goto(url)

    await expectPlausibleInAction(page, {
      action: () => page.click('a'),
      refutedRequests: [{ n: expect.any(String) }],
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
    })

    await expect(page.getByText('Subscription successful')).toBeVisible()
  })
})
