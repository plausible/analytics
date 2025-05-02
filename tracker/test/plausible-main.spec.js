import { expectPlausibleInAction, hideAndShowCurrentTab, e as expect } from './support/test-utils'
import { test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
}

async function openPage(page, config) {
  const configJson = JSON.stringify({ ...DEFAULT_CONFIG, ...config })
  await page.goto(`/plausible-main.html?script_config=${configJson}`)
  await page.waitForTimeout(300)
}

test.describe('plausible-main.js', () => {
  test('triggers pageview and engagement with `local` config enabled', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => openPage(page, { local: true }),
      expectedRequests: [{ n: 'pageview', d: 'example.com', u: expect.stringContaining('plausible-main.html')}]
    })

    await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page, {delay: 2000}),
      expectedRequests: [{n: 'engagement', d: 'example.com', u: expect.stringContaining('plausible-main.html')}],
    })
  })
})
