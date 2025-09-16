import {
  initializePageDynamically,
  serializeWithFunctions
} from './support/initialize-page-dynamically'
import {
  e,
  expectPlausibleInAction,
  hideAndShowCurrentTab,
  isPageviewEvent,
  isEngagementEvent,
  switchByMode
} from './support/test-utils'
import { test, expect } from '@playwright/test'
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
        bodyContent: /* HTML */ `<button onclick="window.plausible('Purchase')">
          Purchase
        </button>`
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
        bodyContent: /* HTML */ `<button onclick="window.plausible('Purchase')">
          Purchase
        </button>`
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
        bodyContent: /* HTML */ `<button onclick="window.plausible('Purchase')">
          Purchase
        </button>`
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
        expectedRequests: ['not an object', 'not an object']
      })
    })
  })
}

test.describe(`transformRequest examples from /docs work`, () => {
  test.beforeEach(async ({ page }) => {
    await page
      .context()
      .route(new RegExp('(http|https)://example\\.com.*'), async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'text/html',
          body: /* HTML */ `<!DOCTYPE html>
            <html>
              <head>
                <title>mocked page</title>
              </head>
              <body>
                mocked page
              </body>
            </html>`
        })
      })
  })

  test('you can omit automatically tracked url property from tagged link clicks', async ({
    page
  }, { testId }) => {
    function omitAutomaticUrlProperty(payload) {
      if (payload.p && payload.p.url) {
        delete payload.p.url
      }
      return payload
    }
    const config = {
      ...DEFAULT_CONFIG,
      transformRequest: omitAutomaticUrlProperty
    }
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: config,
      bodyContent: /* HTML */ `<a
        class="plausible-event-name=Purchase plausible-event-discounted=true"
        href="https://example.com/target?user=sensitive"
        >Purchase</a
      >`
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await page.click('a')
      },
      expectedRequests: [
        {
          n: 'Purchase',
          p: { discounted: 'true' } // <-- no url property
        }
      ],
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
    })
    await expect(page.getByText('mocked page')).toBeVisible()
  })

  for (const { hashBasedRouting, urlSuffix, expectedUrlSuffix } of [
    {
      hashBasedRouting: true,
      urlSuffix:
        '?utm_source=example&utm_medium=referral&utm_campaign=test#fragment',
      expectedUrlSuffix: '#fragment'
    },
    {
      hashBasedRouting: false,
      urlSuffix: '?utm_source=example&utm_medium=referral&utm_campaign=test',
      expectedUrlSuffix: ''
    }
  ]) {
    test(`you can omit UTM properties from pageview urls (hashBasedRouting: ${hashBasedRouting})`, async ({
      page
    }, { testId }) => {
      function omitUTMProperties(payload) {
        const parts = payload.u.split('?')
        let urlWithoutQuery = parts.shift()

        if (payload.h) {
          const fragment = parts.join('?').split('#')[1]
          urlWithoutQuery =
            typeof fragment === 'string'
              ? urlWithoutQuery + '#' + fragment
              : urlWithoutQuery
        }

        payload.u = urlWithoutQuery
        return payload
      }

      const config = {
        ...DEFAULT_CONFIG,
        hashBasedRouting,
        transformRequest: omitUTMProperties
      }

      // the star path is needed for the dynamic page to load when accessing it with query params
      const path = '*'
      const { url } = await initializePageDynamically(page, {
        testId,
        path,
        scriptConfig: config,
        bodyContent: ''
      })

      const [actualUrl] = url.split('*')

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(`${actualUrl}${urlSuffix}`)
          // await page.click('a')
        },
        expectedRequests: [
          {
            n: 'pageview',
            u: `${LOCAL_SERVER_ADDR}${actualUrl}${expectedUrlSuffix}`
          }
        ],
        shouldIgnoreRequest: [isEngagementEvent]
      })
    })
  }

  test('you can track pages using their canonical url', async ({ page }, {
    testId
  }) => {
    function rewriteUrlToCanonicalUrl(payload) {
      // Get the canonical URL element
      const canonicalMeta = document.querySelector('link[rel="canonical"]')
      // Use the canonical URL if it exists, falling back on the regular URL when it doesn't.
      if (canonicalMeta) {
        // @ts-expect-error - canonicalMeta definitely has the href attribute
        payload.u = canonicalMeta.href + window.location.search
      }
      return payload
    }

    // the star path is needed for the dynamic page to load when accessing it with query params
    const nonCanonicalPath = '/products/clothes/shoes/banana-leather-shoe*'
    const { url } = await initializePageDynamically(page, {
      testId,
      path: nonCanonicalPath,
      scriptConfig: /* HTML */ `
        <link rel="canonical" href="/products/banana-leather-shoe" />
        <script type="module">
          import { init, track } from '/tracker/js/npm_package/plausible.js'
          init(
            ${serializeWithFunctions({
              ...DEFAULT_CONFIG,
              transformRequest: rewriteUrlToCanonicalUrl
            })}
          )
        </script>
      `,
      bodyContent: ''
    })
    const [actualUrl] = url.split('*')

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`${actualUrl}?utm_source=example`)
      },
      expectedRequests: [
        {
          n: 'pageview',
          u: `${LOCAL_SERVER_ADDR}/products/banana-leather-shoe?utm_source=example`
        }
      ],
      shouldIgnoreRequest: [isEngagementEvent]
    })
  })
})
