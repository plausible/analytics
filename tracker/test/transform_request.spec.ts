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
  test.describe(`respects "transformRequest" config option (${mode})`, () => {
    test('if "transformRequest" is not a function, nothing happens', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        transformRequest: 123
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
            p: e.toBeUndefined()
          },
          { n: 'engagement', p: e.toBeUndefined() }
        ]
      })
    })

    test('if "transformRequest" is set to be a function that returns null conditionally, those events are not sent', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        transformRequest: (payload) => {
          if (payload.n === 'Purchase') {
            return null
          }
          return payload
        }
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
        bodyContent: `<button onclick="window.plausible('Purchase')">Purchase</button>`
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await page.click('button')
        },
        expectedRequests: [{ n: 'pageview' }],
        refutedRequests: [
          {
            n: 'Purchase'
          }
        ],
        shouldIgnoreRequest: [isEngagementEvent]
      })
    })

    test('if "transformRequest" is set to be a function, it will be called for all events', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        transformRequest: (payload) => {
          return { ...payload, u: '/:masked/path' }
        }
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
        bodyContent: `<button onclick="window.plausible('Purchase')">Purchase</button>`
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await page.click('button')
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          { n: 'pageview', u: '/:masked/path' },
          { n: 'Purchase', u: '/:masked/path' },
          { n: 'engagement', u: '/:masked/path' }
        ]
      })
    })

    test('"transformRequest" does not allow making engagement event props different from pageview event props', async ({
        page
      }, { testId }) => {
        const config = {
          ...DEFAULT_CONFIG,
          transformRequest: (payload) => {
            // @ts-expect-error - defines window.requestCount
            window.requestCount = (window.requestCount ?? 0) + 1
            // @ts-expect-error - window.requestCount is defined
            return { ...payload, p: { requestCount: window.requestCount } }
        }
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
          bodyContent: `<button onclick="window.plausible('Purchase')">Purchase</button>`
        })
  
        await expectPlausibleInAction(page, {
          action: async () => {
            await page.goto(url)
            await page.click('button')
            await hideAndShowCurrentTab(page, { delay: 200 })
          },
          expectedRequests: [
            { n: 'pageview', p: { requestCount: 1 } },
            { n: 'Purchase', p: { requestCount: 2 } },
            { n: 'engagement', p: { requestCount: 1 } }
          ]
        })
      })  

    test('specificity: "transformRequest" runs after custom properties are determined', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        customProperties: () => ({
          author: 'John Smith'
        }),
        transformRequest: (payload) => {
          return { ...payload, p: { author: 'Jane Doe' } }
        }
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
        },
        shouldIgnoreRequest: [isEngagementEvent],
        expectedRequests: [
          {
            n: 'pageview',
            p: {
              author: 'Jane Doe'
            }
          }
        ]
      })
    })

    test('if "transformRequest" is defined to be a function that does not return an object, the request is still attempted', async ({
      page
    }, { testId }) => {
      const config = {
        ...DEFAULT_CONFIG,
        transformRequest: () => 'not an object'
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
        bodyContent: `<button onclick="window.plausible('subscribed from blog', { props: { title: 'A blog post title' } })">Subscribe</button>`
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await page.click('button')
        },
        shouldIgnoreRequest: [isEngagementEvent],
        expectedRequests: ['not an object', 'not an object']
      })
    })
  })
}
