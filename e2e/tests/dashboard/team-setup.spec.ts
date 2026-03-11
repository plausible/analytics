import { test, expect } from '@playwright/test'
import { setupSite } from '../fixtures'
import { randomID } from '../test-utils'

test('submitting team name via Enter key does not crash', async ({
  page,
  request
}) => {
  await setupSite({ page, request })
  await page.goto('/team/setup')

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
})
