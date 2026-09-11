import { test, expect } from '@playwright/test'
import { register, setupSite } from '../fixtures'
import { expectLiveViewConnected, randomID } from '../test-utils'

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

test('create team is blocked when the name is rejected on submit', async ({
  page,
  request
}) => {
  await setupSite({ page, request })
  await page.goto('/team/setup', { waitUntil: 'commit' })

  await expectLiveViewConnected(page)

  const createTeam = page.getByRole('button', { name: 'Create team' })
  const nameInput = page.locator('input[name="team[name]"]')

  await expect(createTeam).toBeEnabled()

  await nameInput.fill('My personal sites')
  await createTeam.click()

  await expect(page.getByText('is reserved')).toBeVisible()
  await expect(page).toHaveURL(/\/team\/setup/)

  await test.step('recovers once the name is fixed', async () => {
    await nameInput.fill('Fixed Team Name')
    await createTeam.click()

    await expect(page).toHaveURL(/\/settings\/team\/general/)
  })

  await expectLiveViewConnected(page)

  await expect(page.locator('input[name="team[name]"]')).toHaveValue(
    'Fixed Team Name'
  )
})

test('creating a team when the user name is long', async ({
  page,
  request
}) => {
  const userID = randomID()
  // exactly 55 characters, prefixed with a unique ID so that `register` finds
  // exactly one activation e-mail for this user
  const longName = `${userID}${'a'.repeat(55)}`.slice(0, 55)
  // the user name gets shortened to fit the 50 character team name limit
  const expectedTeamName = `${longName.slice(0, 43)}'s team`

  const user = {
    name: longName,
    email: `email-${userID}@example.com`,
    password: 'VeryStrongVerySecret'
  }

  await register({ page, request, user })
  await setupSite({ page, request, user })

  await page.goto('/team/setup', { waitUntil: 'commit' })

  await expectLiveViewConnected(page)

  // the page mounts instead of crashing on the over-long suggested name
  await expect(page.getByRole('button', { name: 'Create team' })).toBeVisible()

  const nameInput = page.locator('input[name="team[name]"]')
  const createTeam = page.getByRole('button', { name: 'Create team' })

  await expect(nameInput).toHaveValue(expectedTeamName)

  await test.step('a name over the limit is rejected on submit', async () => {
    await nameInput.fill('b'.repeat(51))
    await createTeam.click()

    await expect(
      page.getByText('should be at most 50 character(s)')
    ).toBeVisible()
    await expect(page).toHaveURL(/\/team\/setup/)
  })

  await test.step('a name carrying a URL scheme is rejected on submit', async () => {
    await nameInput.fill('Cheap meds at https://spam.example.com')
    await createTeam.click()

    await expect(page.getByText('cannot contain a URL')).toBeVisible()
    await expect(page).toHaveURL(/\/team\/setup/)
  })

  await nameInput.fill('Chosen Team Name')

  await createTeam.click()

  await expect(page).toHaveURL(/\/settings\/team\/general/)

  await expectLiveViewConnected(page)

  await expect(page.locator('input[name="team[name]"]')).toHaveValue(
    'Chosen Team Name'
  )
})
