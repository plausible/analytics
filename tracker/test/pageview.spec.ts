import { initializePageDynamically } from './support/initialize-page-dynamically'
import {
  e,
  expectPlausibleInAction,
  hideAndShowCurrentTab,
  isEngagementEvent,
  switchByMode,
  tracker_script_version
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
  test.describe(`"autoCapturePageviews" v2 config option (${mode})`, () => {
    test('if autoCapturePageviews is not explicitly set, it is treated as true and a pageview is sent on navigating to page, engagement tracking is triggered', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG }
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
        bodyContent: 'hello world'
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          {
            n: 'pageview',
            d: config.domain,
            u: `${LOCAL_SERVER_ADDR}${url}`,
            v: tracker_script_version,
            p: e.toBeUndefined()
          },
          {
            n: 'engagement',
            d: config.domain,
            u: `${LOCAL_SERVER_ADDR}${url}`,
            v: tracker_script_version,
            p: e.toBeUndefined()
          }
        ]
      })
    })

    test('if autoCapturePageviews is explicitly set to false, a pageview is not sent on navigating to page, but sending pageviews manually works and it starts engagement tracking logic', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG, autoCapturePageviews: false }
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${JSON.stringify(
              config
            )});</script>`
          },
          mode
        ),
        bodyContent: `
        <a id="alfa" onclick="window.plausible('pageview', { u: '/:masked/alfa' })" href="#">A</a>
        <a id="beta" onclick="window.plausible('pageview', { url: '/:masked/beta' })" href="#">B</a>
        `
      })

      await expectPlausibleInAction(page, {
        action: () => page.goto(url),
        refutedRequests: [{ n: 'pageview' }, { n: 'engagement' }]
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.click('#alfa')
          await page.click('#beta')
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          { n: 'pageview', u: '/:masked/alfa', d: config.domain },
          { n: 'engagement', u: '/:masked/alfa', d: config.domain },
          { n: 'pageview', u: '/:masked/beta', d: config.domain },
          { n: 'engagement', u: '/:masked/beta', d: config.domain }
        ]
      })
    })
  })
}

for (const mode of ['legacy', 'web', 'esm']) {
  test.describe(`pageviews parity legacy/v2 (${mode})`, () => {
    test('sends pageview on navigating to page', async ({ page }, {
      testId
    }) => {
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: DEFAULT_CONFIG,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${JSON.stringify(
              DEFAULT_CONFIG
            )})</script>`,
            legacy: `<script data-domain="${DEFAULT_CONFIG.domain}" async src="/tracker/js/plausible.local.js"></script>`
          },
          mode
        ),
        bodyContent: ''
      })

      await expectPlausibleInAction(page, {
        action: () => page.goto(url),
        expectedRequests: [
          {
            n: 'pageview',
            d: DEFAULT_CONFIG.domain,
            u: `${LOCAL_SERVER_ADDR}${url}`,
            v: tracker_script_version,
            h: e.toBeUndefined(),
          }
        ],
        shouldIgnoreRequest: [isEngagementEvent]
      })
    })
  })
}
