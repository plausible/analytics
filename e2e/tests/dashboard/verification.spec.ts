import { test, expect } from '@playwright/test'
import { setupSite, setVerificationScenario } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

const VERIFICATION_BANNER_SELECTOR = '#verification-ui'
const PROGRESS_MSG_SELECTOR = '#progress'

const SUCCESS_MESSAGE = 'Tracking is active on your site'
const LOADING_STATE_TITLE = 'Verifying your installation'
const LOADING_STATE_CYCLED_MESSAGES = [
  /We're visiting your site to ensure that everything is working/,
  /We're trying to reach your website/,
  /We're verifying that your visitors are being counted correctly/
]

test('verification success', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await setVerificationScenario({
    request,
    domain,
    scenario: 'success',
    options: { slowdown: 500 }
  })

  await page.goto(`/${domain}?verify_installation=true`, { waitUntil: 'commit' })
  await expectLiveViewConnected(page)

  const banner = page.locator(VERIFICATION_BANNER_SELECTOR)
  const progress = banner.locator(PROGRESS_MSG_SELECTOR)

  await expect(banner).toContainText(LOADING_STATE_TITLE)

  for (const msg of LOADING_STATE_CYCLED_MESSAGES) {
    await expect(progress).toHaveText(msg)
  }

  await expect(banner).toContainText(SUCCESS_MESSAGE)

  await banner.getByRole('button', { name: 'Dismiss' }).click()

  await expect(banner).toBeHidden()
  await expect(page).not.toHaveURL(/verify_installation/)

  await page.reload({ waitUntil: 'commit' })

  await expect(page.locator(VERIFICATION_BANNER_SELECTOR)).toBeHidden()
})
