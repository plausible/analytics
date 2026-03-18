import { test, expect } from '@playwright/test'
import { setupSite } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

test('submitting team name via Enter key does not crash', async ({
  page,
  request
}) => {
  await setupSite({ page, request })
  await page.goto('/team/setup')

  await expectLiveViewConnected(page)

  await expect(page.getByRole('button', { name: 'Create Team' })).toBeVisible()

  const nameInput = page.locator('input[name="team[name]"]')

  await nameInput.clear()
  await nameInput.fill('My New Team')

  await nameInput.press('Enter')

  await expect(nameInput).toHaveValue('My New Team')

  // the form had no phx-submit handler and plain HTTP POST fallback was made
  await page.getByRole('button', { name: 'Create Team' }).click()

  await expect(page).toHaveURL(/\/settings\/team\/general/)

  await expectLiveViewConnected(page)

  const nameInput2 = page.locator('input[name="team[name]"]')

  await expect(nameInput2).toHaveValue('My New Team')
})
