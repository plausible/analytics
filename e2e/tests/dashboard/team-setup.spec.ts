import { test, expect } from '@playwright/test'
import { setupSite, subscribeToPlan } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

test('submitting team name via Enter key does not crash', async ({
  page,
  request
}) => {
  await setupSite({ page, request })
  await page.goto('/team/setup', { waitUntil: 'commit' })

  await expectLiveViewConnected(page)

  await expect(page.getByRole('button', { name: 'Create team' })).toBeVisible()

  const nameInput = page.locator('input[name="team[name]"]')

  await nameInput.clear()
  await nameInput.fill('My New Team')

  // Enter submits the whole form directly (single phx-submit handler)
  await nameInput.press('Enter')

  await expect(page).toHaveURL(/\/settings\/team\/general/)

  await expectLiveViewConnected(page)

  const nameInput2 = page.locator('input[name="team[name]"]')

  await expect(nameInput2).toHaveValue('My New Team')
})

test('add another button shows the next row, and disappears once the row limit is reached', async ({
  page,
  request
}) => {
  await setupSite({ page, request })
  await page.goto('/team/setup', { waitUntil: 'commit' })

  await expectLiveViewConnected(page)

  const addAnother = page.getByRole('button', { name: 'Add another' })
  const visibleRows = page.locator('#member-rows > div:not(.hidden)')
  // 10 is the team member limit for a trial account
  const maxRows = 10

  await expect(addAnother).toBeVisible()
  await expect(page.locator('#member-rows > div')).toHaveCount(maxRows)

  await addAnother.click()

  await expect(
    page.locator('#member-rows > div:nth-child(2) input[type="email"]')
  ).toBeFocused()

  // one row already exists by default, one more was just added above
  for (let i = 2; i < maxRows; i++) {
    await addAnother.click()
  }

  await expect(visibleRows).toHaveCount(maxRows)
  await expect(addAnother).toBeHidden()
})

test('removing and re-adding a row', async ({ page, request }) => {
  await setupSite({ page, request })
  // A growth plan with a team member limit of 3
  await subscribeToPlan({ page, planId: '857097' })

  await page.goto('/team/setup', { waitUntil: 'commit' })

  await expectLiveViewConnected(page)

  const addAnother = page.getByRole('button', { name: 'Add another' })
  const visibleRows = page.locator('#member-rows > div:not(.hidden)')

  const row1 = page.locator('#member-row-1')
  const row2 = page.locator('#member-row-2')
  const row3 = page.locator('#member-row-3')

  await row1.locator('input[type="email"]').fill('row1@example.com')
  await row1.getByRole('button', { name: 'Role' }).click()
  await row1.getByRole('option', { name: 'Admin' }).click()

  await addAnother.click()
  await row2.locator('input[type="email"]').fill('row2@example.com')
  await row2.getByRole('button', { name: 'Role' }).click()
  await row2.getByRole('option', { name: 'Editor' }).click()

  await addAnother.click()
  await row3.locator('input[type="email"]').fill('row3@example.com')
  await row3.getByRole('button', { name: 'Role' }).click()
  await row3.getByRole('option', { name: 'Billing' }).click()

  await row2.getByRole('button', { name: 'Remove row' }).click()

  await expect(visibleRows).toHaveCount(2)
  await expect(row2).toBeHidden()

  await expect(row1.locator('input[type="email"]')).toHaveValue(
    'row1@example.com'
  )
  await expect(row1.getByRole('button', { name: 'Role' })).toHaveText('Admin')

  await expect(row3.locator('input[type="email"]')).toHaveValue(
    'row3@example.com'
  )
  await expect(row3.getByRole('button', { name: 'Role' })).toHaveText('Billing')

  await addAnother.click()

  await expect(visibleRows).toHaveCount(3)
  await expect(visibleRows.nth(2)).toHaveAttribute('id', 'member-row-2')

  await expect(row2.locator('input[type="email"]')).toHaveValue('')
  await expect(row2.getByRole('button', { name: 'Role' })).toHaveText('Viewer')
})
