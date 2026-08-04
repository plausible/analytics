import { test, expect } from '@playwright/test'
import { addSite, setupSite, setVerificationScenario } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

const VERIFICATION_BANNER_SELECTOR = '#verification-ui'
const PROGRESS_MSG_SELECTOR = '#progress'
const HEADING_SELECTOR = 'h3'

const SUCCESS_MESSAGE = 'Tracking is active on your site'
const FAILURE_HEADING = "We couldn't detect Plausible on your site"
const LOADING_STATE_TITLE = 'Verifying your installation'
const LOADING_STATE_CYCLED_MESSAGES = [
  /We're visiting your site to ensure that everything is working/,
  /We're trying to reach your website/,
  /We're verifying that your visitors are being counted correctly/
]

test('installation verification', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  const otherDomain = `other.verification.com`
  await addSite({ page, domain: otherDomain })

  const banner = page.locator(VERIFICATION_BANNER_SELECTOR)
  const progress = banner.locator(PROGRESS_MSG_SELECTOR)
  const heading = banner.locator(HEADING_SELECTOR)

  await test.step('restarts when the page is refreshed while verification is ongoing', async () => {
    await setVerificationScenario({
      request,
      domain,
      scenario: 'plausible_not_found',
      options: { slowdown: 500, launch_delay: 500 }
    })

    await page.goto(`/${domain}?verify_installation=true`, {
      waitUntil: 'commit'
    })
    await expectLiveViewConnected(page)

    await expect(banner).toContainText(LOADING_STATE_TITLE)
    await expect(progress).toHaveText(LOADING_STATE_CYCLED_MESSAGES[0]!)
    await expect(progress).toHaveText(LOADING_STATE_CYCLED_MESSAGES[1]!)

    await page.reload({ waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await expect(banner).toContainText(LOADING_STATE_TITLE)

    for (const msg of LOADING_STATE_CYCLED_MESSAGES) {
      await expect(progress).toHaveText(msg)
    }
  })

  await test.step('when finished with failure, refreshing kicks off verification again', async () => {
    await expect(heading).toHaveText(FAILURE_HEADING)

    await page.reload({ waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await expect(banner).toContainText(LOADING_STATE_TITLE)
  })

  await test.step('"Try another URL" reveals the custom URL form instantly, client-side, submitting it kicks off a new run', async () => {
    await setVerificationScenario({
      request,
      domain,
      scenario: 'domain_not_found'
    })

    await page.goto(`/${domain}?verify_installation=true`, {
      waitUntil: 'commit'
    })
    await expectLiveViewConnected(page)

    const defaultActions = banner.locator('#verification-failed-default-actions')
    const customUrlForm = banner.locator('#custom-url-form')
    const tryAnotherUrlLink = banner.getByRole('link', {
      name: 'Try another URL'
    })

    await expect(tryAnotherUrlLink).toBeVisible()
    await expect(customUrlForm).toBeHidden()
    await expect(heading).toHaveText(`We couldn't reach https://${domain}`)

    await tryAnotherUrlLink.click()

    await expect(customUrlForm).toBeVisible()
    await expect(defaultActions).toBeHidden()

    const differentUrl = 'https://differenturl.com'

    await customUrlForm.locator('input[name="custom_url"]').fill(differentUrl)
    await customUrlForm.getByRole('button', { name: 'Verify URL' }).click()

    await expect(heading).toHaveText(`We couldn't reach ${differentUrl}`)
  })

  await test.step('navigating to the dashboard via the site switcher kicks off verification again', async () => {
    await setVerificationScenario({ request, domain, scenario: 'success' })

    await page.goto(`/${otherDomain}`, { waitUntil: 'commit' })

    await page.getByRole('button', { name: otherDomain }).click()
    await page
      .getByTestId('sitemenu')
      .getByRole('link', { name: new RegExp(domain) })
      .click()

    await expect(page).toHaveURL(
      new RegExp(`${domain}\\?verify_installation=true&flow=provisioning`)
    )
    await expectLiveViewConnected(page)

    await expect(banner).toContainText(SUCCESS_MESSAGE)
  })

  await test.step("when finished with success, a page refresh won't bring it back", async () => {
    await page.reload({ waitUntil: 'commit' })

    await expect(page.locator(VERIFICATION_BANNER_SELECTOR)).toHaveCount(0)
  })

  await test.step("flow=review, dismissing while in progress: refresh won't bring it back", async () => {
    await setVerificationScenario({
      request,
      domain,
      scenario: 'success',
      options: { slowdown: 3000 }
    })

    await page.goto(`/${domain}?verify_installation=true&flow=review`, {
      waitUntil: 'commit'
    })
    await expectLiveViewConnected(page)

    await expect(banner).toContainText(LOADING_STATE_TITLE)

    await banner.getByRole('button', { name: 'Dismiss' }).click()

    await expect(banner).toBeHidden()
    await expect(page).not.toHaveURL(/verify_installation/)
    await expect(page).not.toHaveURL(/flow=/)

    await page.reload({ waitUntil: 'commit' })

    await expect(page.locator(VERIFICATION_BANNER_SELECTOR)).toHaveCount(0)
  })

  await test.step('flow=review, finished with failure: refresh kicks off verification again', async () => {
    await setVerificationScenario({
      request,
      domain,
      scenario: 'plausible_not_found'
    })

    await page.goto(`/${domain}?verify_installation=true&flow=review`, {
      waitUntil: 'commit'
    })
    await expectLiveViewConnected(page)

    await expect(heading).toHaveText(FAILURE_HEADING)

    await page.reload({ waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await expect(heading).toHaveText(FAILURE_HEADING)
  })

  await test.step("flow=domain_change, dismissing after finished with failure: refresh won't bring it back", async () => {
    await page.goto(`/${domain}?verify_installation=true&flow=domain_change`, {
      waitUntil: 'commit'
    })
    await expectLiveViewConnected(page)

    await expect(heading).toHaveText(FAILURE_HEADING)

    await banner.getByRole('button', { name: 'Dismiss' }).click()

    await expect(banner).toBeHidden()
    await expect(page).not.toHaveURL(/verify_installation/)
    await expect(page).not.toHaveURL(/flow=/)

    await page.reload({ waitUntil: 'commit' })

    await expect(page.locator(VERIFICATION_BANNER_SELECTOR)).toHaveCount(0)
  })

  await test.step("flow=domain_change, finished with success: refresh won't bring it back", async () => {
    await setVerificationScenario({ request, domain, scenario: 'success' })

    await page.goto(`/${domain}?verify_installation=true&flow=domain_change`, {
      waitUntil: 'commit'
    })
    await expectLiveViewConnected(page)

    await expect(banner).toContainText(SUCCESS_MESSAGE)

    await page.reload({ waitUntil: 'commit' })

    await expect(page.locator(VERIFICATION_BANNER_SELECTOR)).toHaveCount(0)
  })
})
