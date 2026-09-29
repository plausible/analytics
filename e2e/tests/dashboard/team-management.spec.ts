import { test, expect, Page } from '@playwright/test'
import { setupSite } from '../fixtures'
import {
  closeFlashMessage,
  expectLiveViewConnected,
  hasFlashMessage,
  hasNoFlashMessage,
  randomID
} from '../test-utils'

async function createTeam(page: Page) {
  await page.goto('/team/setup', { waitUntil: 'commit' })
  await expectLiveViewConnected(page)
  await page.getByRole('button', { name: 'Create team' }).click()
  await expect(page).toHaveURL(/\/settings\/team\/general/)
  await expectLiveViewConnected(page)
  // so that tests start without a flash
  await closeFlashMessage(page)
}

async function submitInviteForm(
  page: Page,
  { email, roleOptionName }: { email: string; roleOptionName: string | RegExp }
) {
  await page.getByPlaceholder('Enter e-mail').fill(email)
  await page.locator('#input-role-picker-trigger').click()
  await page
    .locator('#input-role-picker')
    .getByRole('option', { name: roleOptionName })
    .click()
  await page.getByRole('button', { name: 'Invite' }).click()
}

test('lowering your own role asks for confirmation', async ({
  page,
  request
}) => {
  const { user } = await setupSite({ page, request })
  await createTeam(page)

  // The only owner can't change their own role, so a second (invited) owner
  // is needed for the self-demotion options to become selectable.
  const ownerEmail = `owner-${randomID()}@example.com`
  await submitInviteForm(page, { email: ownerEmail, roleOptionName: /^Owner/ })
  await expect(
    page.getByRole('button', { name: `Role for ${ownerEmail}:` })
  ).toContainText('Owner')

  const trigger = page.getByRole('button', { name: `Role for ${user.email}:` })
  const options = page.getByRole('listbox', {
    name: `Role for ${user.email}:`
  })

  const dialogs: string[] = []
  const answerNextDialog = (accept: boolean) =>
    page.once('dialog', async (dialog) => {
      dialogs.push(dialog.message())
      await (accept ? dialog.accept() : dialog.dismiss())
    })

  await expect(trigger).toBeEnabled()
  await expect(trigger).toContainText('Owner')

  await test.step('lower your own role, but cancel the confirmation dialog (mouse)', async () => {
    answerNextDialog(false)

    await trigger.click()
    await options.getByRole('option', { name: /^Viewer/ }).click()

    expect(dialogs).toHaveLength(1)
    expect(dialogs[0]).toContain("You're about to lower your own role")
    await expect(trigger).toContainText('Owner')
    await hasNoFlashMessage(page)

    // Close the listbox that remained open because the option selection click didn't
    // go through -- our confirmation dialog prevented it from bubbling up to Prima.
    await page.keyboard.press('Escape')
  })

  await test.step('lower your own role, but cancel the confirmation dialog (keyboard)', async () => {
    answerNextDialog(false)

    await trigger.focus()
    await page.keyboard.press('ArrowUp')
    await expect(
      options.getByRole('option', { name: /^Viewer/ })
    ).toHaveAttribute('data-focus')
    await page.keyboard.press('Enter')

    expect(dialogs).toHaveLength(2)
    await expect(trigger).toContainText('Owner')
    await hasNoFlashMessage(page)

    // Close the listbox that remained open because the option selection click didn't
    // go through -- our confirmation dialog prevented it from bubbling up to Prima.
    await page.keyboard.press('Escape')
  })

  await test.step('lower your own role and confirm (mouse)', async () => {
    answerNextDialog(true)

    await trigger.click()
    await options.getByRole('option', { name: /^Viewer/ }).click()

    // The change reaches the server, which rejects it: the other owner has only
    // been invited so far.
    await hasFlashMessage(page, 'The team has to have at least one owner')

    // asked once: phoenix_html must not ask again as the confirmed click bubbles up
    expect(dialogs).toHaveLength(3)

    // Known bug, to be fixed soon: the trigger keeps showing the rejected role
    // until the page is reloaded. Once fixed, the reload won't be necessary.
    await page.reload()
    await expectLiveViewConnected(page)

    await expect(trigger).toContainText('Owner')
  })

  await test.step('lower your own role and confirm (keyboard)', async () => {
    answerNextDialog(true)

    await trigger.focus()
    await page.keyboard.press('ArrowUp')
    await expect(
      options.getByRole('option', { name: /^Viewer/ })
    ).toHaveAttribute('data-focus')
    await page.keyboard.press('Enter')

    // The change reaches the server, which rejects it: the other owner has only
    // been invited so far.
    await hasFlashMessage(page, 'The team has to have at least one owner')

    // asked once: phoenix_html must not ask again as the confirmed click bubbles up
    expect(dialogs).toHaveLength(4)

    // Known bug, to be fixed soon: the trigger keeps showing the rejected role
    // until the page is reloaded. Once fixed, the reload won't be necessary.
    await page.reload()
    await expectLiveViewConnected(page)

    await expect(trigger).toContainText('Owner')
  })
})
