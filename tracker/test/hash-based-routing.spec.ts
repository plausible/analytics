import { initializePageDynamically } from './support/initialize-page-dynamically'
import {
  e,
  expectPlausibleInAction,
  hideAndShowCurrentTab,
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
  test.describe(`respects hashBasedRouting config option (${mode})`, () => {
    test('pageviews and engagement events are sent without "h" parameter if hashBasedRouting is not set', async ({
      page
    }, { testId }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: DEFAULT_CONFIG,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${JSON.stringify(
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
            h: e.toBeUndefined()
          },
          { n: 'engagement', h: e.toBeUndefined() }
        ]
      })
    })

    test('pageviews and engagement events are sent with "h:1" parameter if hashBasedRouting is set to true', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG, hashBasedRouting: true }
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${JSON.stringify(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: ''
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(`${url}#page1`)
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          {
            n: 'pageview',
            h: 1,
            u: `${LOCAL_SERVER_ADDR}${url}#page1`
          },
          {
            n: 'engagement',
            h: 1,
            u: `${LOCAL_SERVER_ADDR}${url}#page1`
          }
        ]
      })
    })
  })
}

test.describe('hash-based routing (legacy)', () => {
  test('pageviews and engagement events are sent with "h:1" parameter if using the hash extension', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: /* HTML */ `<script
        data-domain="${DEFAULT_CONFIG.domain}"
        async
        src="/tracker/js/plausible.hash.local.js"
      ></script>`,
      bodyContent: ''
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`${url}#page1`)
        await hideAndShowCurrentTab(page, { delay: 200 })
      },
      expectedRequests: [
        {
          n: 'pageview',
          h: 1,
          u: `${LOCAL_SERVER_ADDR}${url}#page1`
        },
        {
          n: 'engagement',
          h: 1,
          u: `${LOCAL_SERVER_ADDR}${url}#page1`
        }
      ]
    })
  })
})
