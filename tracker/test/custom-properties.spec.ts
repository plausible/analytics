import {
  initializePageDynamically,
  serializeWithFunctions
} from './support/initialize-page-dynamically'
import {
  e,
  expectPlausibleInAction,
  hideAndShowCurrentTab,
  isEngagementEvent,
  switchByMode
} from './support/test-utils'
import { test } from '@playwright/test'
import { ScriptConfig } from './support/types'
import { LOCAL_SERVER_ADDR } from './support/server'
const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

for (const mode of ['web', 'esm']) {
  test.describe(`respects "customProperties" config option (${mode})`, () => {
    test('if "customProperties" is not set, pageviews and engagement events are sent without "p" parameter', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: DEFAULT_CONFIG,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${serializeWithFunctions(
              DEFAULT_CONFIG
            )})</script>`
          },
          mode
        ),
        bodyContent: ''
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          {
            n: 'pageview',
            p: e.toBeUndefined()
          },
          { n: 'engagement', p: e.toBeUndefined() }
        ]
      })
    })

    test('if "customProperties" is set to a fixed value, pageviews and engagement events are sent with "p" parameter', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        customProperties: { author: 'John Smith' }
      }
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${serializeWithFunctions(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: ''
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          {
            n: 'pageview',
            p: config.customProperties
          },
          { n: 'engagement', p: config.customProperties }
        ]
      })
    })

    test('if "customProperties" is set to be a function, pageviews and engagement events are sent with "p" parameter', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        customProperties: (eventName) => ({
          author: 'John Smith',
          eventName: eventName,
          documentTitle: document.title
        })
      }

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${serializeWithFunctions(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: ''
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          {
            n: 'pageview',
            p: {
              author: 'John Smith',
              eventName: 'pageview',
              documentTitle: 'Plausible Playwright tests'
            }
          },
          {
            n: 'engagement',
            // Engagement event is sent with the same custom properties as the pageview event, customProperties function does not get called for these!
            p: {
              author: 'John Smith',
              eventName: 'pageview',
              documentTitle: 'Plausible Playwright tests'
            }
          }
        ]
      })
    })

    test('specificity: props given in "track" call override any custom properties set in "customProperties"', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        customProperties: () => ({
          author: 'John Smith',
          title: document.title
        })
      }

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${serializeWithFunctions(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: /* HTML */ `<button
          onclick="window.plausible('subscribed from blog', { props: { title: 'A blog post title' } })"
        >
          Subscribe
        </button>`
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await page.click('button')
        },
        shouldIgnoreRequest: [isEngagementEvent],
        expectedRequests: [
          {
            n: 'pageview',
            p: {
              author: 'John Smith',
              title: 'Plausible Playwright tests'
            }
          },
          {
            n: 'subscribed from blog',
            p: {
              author: 'John Smith',
              title: 'A blog post title'
            }
          }
        ]
      })
    })

    test('if "customProperties" is defined as not an object or function, it is ignored', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        customProperties: 123
      }

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${serializeWithFunctions(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: /* HTML */ `<button
          onclick="window.plausible('subscribed from blog', { props: { title: 'A blog post title' } })"
        >
          Subscribe
        </button>`
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await page.click('button')
        },
        shouldIgnoreRequest: [isEngagementEvent],
        expectedRequests: [
          {
            n: 'pageview',
            p: e.toBeUndefined()
          },
          {
            n: 'subscribed from blog',
            p: {
              title: 'A blog post title'
            }
          }
        ]
      })
    })

    test('if "customProperties" is defined to be a function that does not return an object, its output is ignored', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        customProperties: () => 'not an object'
      }

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${serializeWithFunctions(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: /* HTML */ `<button
          onclick="window.plausible('subscribed from blog', { props: { title: 'A blog post title' } })"
        >
          Subscribe
        </button>`
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await page.click('button')
        },
        shouldIgnoreRequest: [isEngagementEvent],
        expectedRequests: [
          {
            n: 'pageview',
            p: e.toBeUndefined()
          },
          {
            n: 'subscribed from blog',
            p: {
              title: 'A blog post title'
            }
          }
        ]
      })
    })
  })
}
