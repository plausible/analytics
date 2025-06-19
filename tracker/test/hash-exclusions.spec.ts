import { initializePageDynamically } from './support/initialize-page-dynamically'
import { expectPlausibleInAction } from './support/test-utils'
import { test } from '@playwright/test'

test.describe('combination of hash and exclusions script extensions', () => {
  test('excludes by hash part of the URL', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-exclude='/**#*/hash/**/ignored' src="/tracker/js/plausible.exclusions.hash.local.js"></script>`,
      bodyContent: ''
    })
    await expectPlausibleInAction(page, {
      action: () => page.goto(`${url}#this/hash/should/be/ignored`),
      expectedRequests: [],
      awaitedRequestCount: 1
    })
  })
})
