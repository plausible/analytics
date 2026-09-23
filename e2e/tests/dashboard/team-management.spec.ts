import { test, expect } from '@playwright/test'
import { setupSite, addTeamMember } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

test('cancelling the self-demotion confirmation keeps the previous role selected', async ({
  page,
  request
}) => {
  const { domain, user } = await setupSite({ page, request })

  await page.goto('/team/setup', { waitUntil: 'commit' })
  await expectLiveViewConnected(page)
  await page.getByRole('button', { name: 'Create team' }).click()
  await expect(page).toHaveURL(/\/settings\/team\/general/)

  await addTeamMember({
    request,
    domain,
    email: 'owner2@example.com',
    role: 'owner'
  })

  await page.goto('/settings/team/general', { waitUntil: 'commit' })
  await expectLiveViewConnected(page)

  const selfRow = page
    .locator('#member-list div[data-test-kind="member"]')
    .filter({ hasText: user.email })

  const roleTrigger = selfRow.getByRole('button', { name: 'Role' })

  await test.step('cancelling leaves the role and its display untouched', async () => {
    await roleTrigger.click()

    page.once('dialog', (dialog) => dialog.dismiss())
    await selfRow.getByRole('option', { name: 'Billing' }).click()

    await expect(roleTrigger).toHaveText('Owner')

    await page.reload({ waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await expect(roleTrigger).toHaveText('Owner')
  })

  await test.step('confirming applies the role change as usual', async () => {
    await roleTrigger.click()

    page.once('dialog', (dialog) => dialog.accept())
    await selfRow.getByRole('option', { name: 'Billing' }).click()

    await expect(roleTrigger).toHaveText('Billing')

    await page.reload({ waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await expect(roleTrigger).toHaveText('Billing')
  })
})
