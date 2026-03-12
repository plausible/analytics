import { test, expect } from '@playwright/test'
import { setupSite } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

test('submitting team name via Enter key does not crash', async ({
  page,
  request
}) => {
  await setupSite({ page, request })
  await page.goto('/team/setup')

  // await expectLiveViewConnected(page)
  //       at test-utils.ts:5
  //
  // 3 |
  //   4 | export async function expectLiveViewConnected(page: Page) {
  //   > 5 |   return expect(page.locator('.phx-connected')).toHaveCount(1)
  //     |                                                 ^
  //     6 | }
  //     7 |
 

  await expect(
    page.getByRole('button', { name: 'Create Team' })
  ).toBeVisible()

  const nameInput = page.locator('input[name="team[name]"]')

  await nameInput.clear()
  await nameInput.fill('My New Team')

  await nameInput.press('Enter')

  // the form had no phx-submit handler and plain HTTP POST fallback was made
  await expect(
    page.getByRole('button', { name: 'Create Team' })
  ).toBeVisible()

  await expect(nameInput).toHaveValue('My New Team')

  // should follow a redirect?
  await page.goto('/settings/team/general')

  await expectLiveViewConnected(page)

  const nameInput2 = page.locator('input[name="team[name]"]')
  // fails:
  await expect(nameInput2).toHaveValue('My New Team')
})
