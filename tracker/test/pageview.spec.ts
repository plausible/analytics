import { initializePageDynamically } from './support/initialize-page-dynamically'
import {
  expectPlausibleInAction,
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
            legacy:
              '<script defer src="/tracker/js/plausible.local.js"></script>'
          },
          mode
        ),
        bodyContent: ''
      })

      await expectPlausibleInAction(page, {
        action: () => page.goto(url),
        expectedRequests: [{ n: 'pageview', v: tracker_script_version }],
        shouldIgnoreRequest: [isEngagementEvent]
      })
    })
  })
}
