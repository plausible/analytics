import { test, expect } from '@playwright/test'
import type { APIRequestContext, Page } from '@playwright/test'
import {
  setupSite,
  populateStats,
  register,
  createSharedLink,
  logout,
  makeSitePublic,
  subscribeToPlan
} from '../fixtures'
import { expectLiveViewConnected, randomID } from '../test-utils'

test.use({ locale: 'en-GB' })

async function seedAnnotationSite({
  page,
  request,
  user
}: {
  page: Page
  request: APIRequestContext
  user: { email: string; name: string; password: string }
}) {
  await register({ page, request, user })
  const { domain } = await setupSite({ page, request, user })
  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 1,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-06-29 10:00:00'
      }
    ]
  })
  return { domain }
}

async function createSiteAnnotationViaUI({
  page,
  domain,
  note
}: {
  page: Page
  domain: string
  note: string
}) {
  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })

  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  const mondayBucket = page.getByTestId('graph-dot-series-1-bucket-0')
  await mondayBucket.hover()
  const tooltip = page.getByTestId('graph-tooltip')
  await expect(tooltip).toBeVisible()
  await mondayBucket.click({ button: 'right' })

  await tooltip.getByRole('button', { name: 'Add note' }).click()
  await page.getByRole('textbox', { name: 'Note' }).fill(note)
  await page.getByRole('radio', { name: /Site note/ }).check()
  await page.getByRole('button', { name: 'Save' }).click()

  await expect(page.getByTestId('annotation-marker-on-bucket-0')).toBeVisible()
}

test('user can create annotations across granularities, edit, and delete them', async ({
  page,
  request
}) => {
  const user = {
    email: `site-owner-for-annotations-${randomID()}@example.com`,
    // name matters in this test
    name: 'J R.R. Smith',
    password: 'VeryStrongVerySecret'
  }
  await register({
    page,
    request,
    user
  })
  const { domain } = await setupSite({ page, request, user })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 0,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-04-01 00:00:00'
      },
      {
        user_id: 1,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-06-29 05:00:00'
      },
      {
        user_id: 2,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-06-29 10:00:00'
      }
    ]
  })

  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })

  const mondayIn7d = page.getByTestId('graph-dot-series-1-bucket-0')
  const mondayMarker7d = page.getByTestId('annotation-marker-on-bucket-0')

  const tooltip = page.getByTestId('graph-tooltip')

  // inputs in create / edit modals
  const noteField = page.getByRole('textbox', { name: 'Note' })
  const saveButton = page.getByRole('button', { name: 'Save' })

  const siteNoteText = 'Company-wide: launch day'
  const personalNoteText = 'Feature available for 50% of customers'
  const updatedNoteText = 'Feature fully released (correction)'

  const personalNoteAttribution = 'Personal note • 29 Jun 10:00'
  const siteNoteAttribution = `${user.name} • 29 Jun`

  // Asserts the tooltip's annotation list matches provided list exactly
  const expectTooltipAnnotations = async (
    expected: Array<{ note: string; attribution: string }>
  ) => {
    const rows = tooltip.locator('div.group')
    await expect(rows).toHaveCount(expected.length)
    for (const [i, { note, attribution }] of expected.entries()) {
      const row = rows.nth(i)
      await expect(row).toContainText(note)
      await expect(row.getByText(attribution, { exact: true })).toBeVisible()
    }
  }

  // Needed because the tests expect a particular graph interval
  const setGraphInterval = async (label: 'Hours' | 'Days' | 'Months') => {
    await page.getByTestId('dashboard-options-menu').click()
    await page.getByRole('button', { name: label, exact: true }).click()
    await page.keyboard.press('Escape')
  }

  await test.step('in 7d view, create date-granularity site annotation on Monday', async () => {
    await setGraphInterval('Days')

    // hovered tooltip
    await mondayIn7d.hover()
    await expect(tooltip).toBeVisible()
    await expectTooltipAnnotations([])

    await expect(tooltip).toContainText('Click to view day')
    await expect(tooltip).toContainText('Right click for more actions')

    // persisted tooltip
    await mondayIn7d.click({ button: 'right' })
    await expect(tooltip).toBeVisible()

    await expect(tooltip.locator('button')).toContainText([
      'Add note',
      'View day'
    ])
    await tooltip.getByRole('button', { name: 'Add note' }).click()

    const createModalHeading = page.getByRole('heading', {
      name: 'Add note for Mon, 29 Jun',
      exact: true
    })
    await expect(createModalHeading).toBeVisible()

    await noteField.fill(siteNoteText)
    await page.getByRole('radio', { name: /Site note/ }).check()
    await saveButton.click()

    await expect(createModalHeading).toBeHidden()
    await expect(mondayMarker7d).toBeVisible()
  })

  await test.step('right-click Monday and zoom in via "View day"', async () => {
    await mondayIn7d.hover()
    await expectTooltipAnnotations([
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])

    await mondayIn7d.click({ button: 'right' })

    await tooltip.getByRole('button', { name: 'View day' }).click()
    await expect(page).toHaveURL(/period=day&date=2026-06-29/)

    // Date-granularity annotations don't map to hour buckets — no marker in day view.
    await expect(page.getByTestId(/^annotation-marker-on-bucket-/)).toHaveCount(
      0
    )
  })

  await test.step('in day view, create minute-granularity personal annotation at 10:00', async () => {
    await setGraphInterval('Hours')

    const hour10InDay = page.getByTestId('graph-dot-series-1-bucket-10')
    await hour10InDay.hover()
    await hour10InDay.click({ button: 'right' })
    await expect(tooltip).toBeVisible()

    await tooltip.getByRole('button', { name: 'Add note' }).click()

    const createModalHeading = page.getByRole('heading', {
      name: 'Add note for Mon, 29 Jun at 10:00',
      exact: true
    })
    await expect(createModalHeading).toBeVisible()
    await expect(tooltip).toBeHidden()

    await noteField.fill(personalNoteText)
    await saveButton.click()

    await expect(createModalHeading).toBeHidden()
    await expect(
      page.getByTestId('annotation-marker-on-bucket-10')
    ).toBeVisible()
  })

  await test.step('zoom back out to 7d, both annotations are visible on Monday', async () => {
    await page.goBack({ waitUntil: 'commit' })
    await setGraphInterval('Days')

    await expect(mondayMarker7d).toBeVisible()

    const expectedOnMonday = [
      { note: personalNoteText, attribution: personalNoteAttribution },
      { note: siteNoteText, attribution: siteNoteAttribution }
    ]

    await mondayIn7d.hover()
    await expect(tooltip).toBeVisible()
    await expectTooltipAnnotations(expectedOnMonday)

    await mondayIn7d.click({ button: 'right' })
    await expect(tooltip).toBeVisible()
    await expectTooltipAnnotations(expectedOnMonday)
  })

  await test.step('edit personal annotation', async () => {
    const personalRow = tooltip.locator('div.group', {
      hasText: personalNoteText
    })
    await personalRow.hover()
    await personalRow.getByRole('button', { name: 'Edit note' }).click()

    const updateModalHeading = page.getByRole('heading', {
      name: 'Update note for Mon, 29 Jun at 10:00',
      exact: true
    })
    await expect(updateModalHeading).toBeVisible()
    await expect(tooltip).toBeHidden()
    await expect(noteField).toHaveValue(personalNoteText)

    await noteField.fill(updatedNoteText)
    await saveButton.click()

    await expect(updateModalHeading).toBeHidden()

    await mondayIn7d.hover()
    await mondayIn7d.click({ button: 'right' })
    await expectTooltipAnnotations([
      { note: updatedNoteText, attribution: personalNoteAttribution },
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])
  })

  await test.step('delete personal annotation', async () => {
    const personalNote = tooltip.locator('div.group', {
      hasText: updatedNoteText
    })
    await personalNote.hover()
    await personalNote.getByRole('button', { name: 'Edit note' }).click()

    const updateModalHeading = page.getByRole('heading', {
      name: 'Update note for Mon, 29 Jun at 10:00',
      exact: true
    })
    await expect(updateModalHeading).toBeVisible()

    await page.getByRole('button', { name: 'Delete note' }).click()

    const deleteModalHeading = page.getByRole('heading', {
      name: `Delete personal note "${updatedNoteText}"?`,
      exact: true
    })
    await expect(deleteModalHeading).toBeVisible()
    await expect(updateModalHeading).toBeHidden()

    await page.getByRole('button', { name: 'Delete', exact: true }).click()

    await expect(deleteModalHeading).toBeHidden()
    await mondayIn7d.hover()
    await expectTooltipAnnotations([
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])
    await expect(mondayMarker7d).toBeVisible()
  })

  await test.step('date annotations are shown for All period', async () => {
    await page.getByTestId('current-query-period').click()
    await page
      .getByTestId('query-period-picker')
      .getByRole('link', { name: 'All time' })
      .click()
    await expect(page).toHaveURL(/period=all/)

    const marker = page.getByTestId(/^annotation-marker-on-bucket-/)
    await expect(marker).toHaveCount(1)
    await expect(marker).toBeVisible()

    await setGraphInterval('Months')
    await page.getByText('June 2026', { exact: true }).hover()
    await expectTooltipAnnotations([
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])
  })
})

test('shared link viewer sees site annotations but cannot add or edit them', async ({
  page,
  request
}) => {
  const user = {
    email: `owner-shared-link-${randomID()}@example.com`,
    name: `Owner ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  const noteText = 'Deploy: v2.0 released'

  const { domain } = await seedAnnotationSite({ page, request, user })
  await createSiteAnnotationViaUI({ page, domain, note: noteText })

  const sharedLink = await createSharedLink({
    page,
    domain,
    name: `annotations-${randomID()}`
  })
  await logout(page)

  const sharedLinkWithPeriod = `${sharedLink}&period=7d&date=2026-07-06&comparison=off`
  await page.goto(sharedLinkWithPeriod, { waitUntil: 'commit' })
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  // Marker is visible on the graph
  await expect(page.getByTestId('annotation-marker-on-bucket-0')).toBeVisible()

  const tooltip = page.getByTestId('graph-tooltip')
  const bucket = page.getByTestId('graph-dot-series-1-bucket-0')

  // Hover shows the note in the tooltip
  await bucket.hover()
  await expect(tooltip).toBeVisible()
  await expect(tooltip).toContainText(noteText)

  // Right-click persists the tooltip but does not offer Add note / Edit note
  await bucket.click({ button: 'right' })
  await expect(tooltip).toBeVisible()
  await expect(tooltip.getByRole('button', { name: 'Add note' })).toHaveCount(0)
  await expect(tooltip.getByRole('button', { name: 'Edit note' })).toHaveCount(
    0
  )
})

test('public site viewer sees site annotations but cannot add or edit them', async ({
  page,
  request
}) => {
  const user = {
    email: `owner-public-site-${randomID()}@example.com`,
    name: `Owner ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  const noteText = 'Public site: milestone'

  const { domain } = await seedAnnotationSite({ page, request, user })
  await createSiteAnnotationViaUI({ page, domain, note: noteText })

  await makeSitePublic({ page, domain })
  await logout(page)

  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  await expect(page.getByTestId('annotation-marker-on-bucket-0')).toBeVisible()

  const tooltip = page.getByTestId('graph-tooltip')
  const bucket = page.getByTestId('graph-dot-series-1-bucket-0')

  await bucket.hover()
  await expect(tooltip).toBeVisible()
  await expect(tooltip).toContainText(noteText)

  await bucket.click({ button: 'right' })
  await expect(tooltip).toBeVisible()
  await expect(tooltip.getByRole('button', { name: 'Add note' })).toHaveCount(0)
  await expect(tooltip.getByRole('button', { name: 'Edit note' })).toHaveCount(
    0
  )
})

async function inviteGuestMember({
  page,
  domain,
  email,
  role
}: {
  page: Page
  domain: string
  email: string
  role: 'viewer' | 'editor'
}) {
  await page.goto(`/sites/${domain}/memberships/invite`, {
    waitUntil: 'commit'
  })
  await page.getByLabel('Email address').fill(email)
  await page
    .getByLabel(role === 'viewer' ? 'Guest Viewer' : 'Guest Editor')
    .check()
  await page.getByRole('button', { name: 'Invite' }).click()
  await expect(page.locator('body')).toContainText(
    `${email} has been invited to ${domain}`
  )
}

async function registerAsGuestFromInvitation({
  page,
  request,
  invitedEmail,
  guestName,
  guestPassword
}: {
  page: Page
  request: APIRequestContext
  invitedEmail: string
  guestName: string
  guestPassword: string
}) {
  const response = await request.get('/sent-emails-api/emails.json')
  const emails: Array<{
    to: string[][]
    subject: string
    html_body: string
  }> = await response.json()

  const invitationEmail = emails
    .filter(
      (e) =>
        e.to![0]![1] === invitedEmail &&
        /invited you to join/i.test(e.html_body)
    )
    .pop()
  expect(invitationEmail).toBeTruthy()

  // Nanoid's default alphabet includes underscore; keep the character class in sync.
  const match = invitationEmail!.html_body.match(
    /\/register\/invitation\/([A-Za-z0-9_-]+)/
  )
  expect(match).toBeTruthy()
  const invitationPath = `/register/invitation/${match![1]}`

  await page.goto(invitationPath, { waitUntil: 'commit' })
  await expectLiveViewConnected(page)
  await page.getByLabel('Full name').fill(guestName)
  await page.getByLabel('Password', { exact: true }).fill(guestPassword)
  await page.getByLabel('Confirm password', { exact: true }).fill(guestPassword)
  // Full name may be reset by an intervening phx-change on password fields;
  // re-assert it right before submitting.
  await expect(page.getByLabel('Full name')).toHaveValue(guestName)
  await page.getByRole('button', { name: 'Create my account' }).click()

  // New user must activate (verification code sent as part of registration)
  await expect(
    page.getByRole('heading', { name: 'Activate your account' })
  ).toBeVisible()

  const activationResponse = await request.get('/sent-emails-api/emails.json')
  const allEmails: Array<{ to: string[][]; subject: string }> =
    await activationResponse.json()
  const codeEmail = allEmails
    .filter(
      (e) =>
        e.to![0]![1] === invitedEmail &&
        /verification code/i.test(e.subject)
    )
    .pop()
  expect(codeEmail).toBeTruthy()
  const [code] = codeEmail!.subject.split(' ')
  await page.locator('input[name=code]').fill(code!)
  await page.getByRole('button', { name: 'Activate' }).click()

  // Now on sites listing — accept the pending invitation. The button_link component
  // renders an <a> with method="post" and a JS handler.
  await page.getByRole('link', { name: 'Accept' }).click()
  await expect(page.locator('body')).toContainText('You now have access to')
}

test('guest viewer can add personal notes but not site notes', async ({
  page,
  request
}) => {
  const owner = {
    email: `owner-guest-viewer-${randomID()}@example.com`,
    name: `Owner ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  const guest = {
    email: `guest-viewer-${randomID()}@example.com`,
    name: `Guest Viewer ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  const siteNoteText = 'Owner: campaign started'
  const personalNoteText = 'My personal note as guest viewer'

  const { domain } = await seedAnnotationSite({
    page,
    request,
    user: owner
  })
  await createSiteAnnotationViaUI({ page, domain, note: siteNoteText })
  await inviteGuestMember({ page, domain, email: guest.email, role: 'viewer' })
  await logout(page)

  await registerAsGuestFromInvitation({
    page,
    request,
    invitedEmail: guest.email,
    guestName: guest.name,
    guestPassword: guest.password
  })

  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  // Site annotation from owner is visible to the guest viewer
  await expect(page.getByTestId('annotation-marker-on-bucket-0')).toBeVisible()

  const tooltip = page.getByTestId('graph-tooltip')
  const bucket = page.getByTestId('graph-dot-series-1-bucket-0')
  await bucket.hover()
  await expect(tooltip).toContainText(siteNoteText)

  // Guest viewer can add note, but the Site note option must be disabled
  await bucket.click({ button: 'right' })
  await tooltip.getByRole('button', { name: 'Add note' }).click()
  await page.getByRole('textbox', { name: 'Note' }).fill(personalNoteText)

  const siteRadio = page.getByRole('radio', { name: /Site note/ })
  const saveBtn = page.getByRole('button', { name: 'Save' })

  // Site note option is disabled for a role without permission, and hovering
  // the row surfaces the reason in a tooltip.
  await expect(siteRadio).toBeDisabled()
  await page.getByText(/Site note/).hover()
  await expect(
    page.getByText(/don't have enough permissions/i)
  ).toBeVisible()

  // Personal is preselected and Save is enabled — guest viewer can save it
  await expect(saveBtn).toBeEnabled()
  await saveBtn.click()

  await bucket.hover()
  await expect(tooltip).toContainText(personalNoteText)
  await expect(tooltip).toContainText(siteNoteText)
})

test('guest editor can add and edit site annotations', async ({
  page,
  request
}) => {
  const owner = {
    email: `owner-guest-editor-${randomID()}@example.com`,
    name: `Owner ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  const guest = {
    email: `guest-editor-${randomID()}@example.com`,
    name: `Guest Editor ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  const guestSiteNoteText = 'Guest editor: fixed prod issue'

  const { domain } = await seedAnnotationSite({
    page,
    request,
    user: owner
  })
  await inviteGuestMember({ page, domain, email: guest.email, role: 'editor' })
  await logout(page)

  await registerAsGuestFromInvitation({
    page,
    request,
    invitedEmail: guest.email,
    guestName: guest.name,
    guestPassword: guest.password
  })

  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  const tooltip = page.getByTestId('graph-tooltip')
  const bucket = page.getByTestId('graph-dot-series-1-bucket-0')

  await bucket.hover()
  await expect(tooltip).toBeVisible()
  await bucket.click({ button: 'right' })
  await tooltip.getByRole('button', { name: 'Add note' }).click()
  await page.getByRole('textbox', { name: 'Note' }).fill(guestSiteNoteText)
  await page.getByRole('radio', { name: /Site note/ }).check()
  await expect(page.getByText(/don't have enough permissions/i)).toHaveCount(0)
  await page.getByRole('button', { name: 'Save' }).click()

  await expect(page.getByTestId('annotation-marker-on-bucket-0')).toBeVisible()

  await bucket.hover()
  await expect(tooltip).toContainText(guestSiteNoteText)
  await expect(tooltip).toContainText(guest.name)
})

test.describe('mobile viewport', () => {
  test.use({
    viewport: { width: 390, height: 844 },
    hasTouch: true
  })

  test('annotations are visible and can be tapped on mobile', async ({
    page,
    request
  }) => {
    const user = {
      email: `owner-mobile-${randomID()}@example.com`,
      name: `Owner ${randomID()}`,
      password: 'VeryStrongVerySecret'
    }
    const noteText = 'Mobile: release marker'

    await register({ page, request, user })
    const { domain } = await setupSite({ page, request, user })
    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 1,
          name: 'pageview',
          pathname: '/',
          timestamp: '2026-06-29 10:00:00'
        }
      ]
    })

    // Seed a site annotation via a desktop-sized context so the setup is reliable
    // (mobile "add note" is exercised separately via tap below).
    await page.setViewportSize({ width: 1280, height: 900 })
    await createSiteAnnotationViaUI({ page, domain, note: noteText })

    // Now switch to mobile viewport to exercise the annotation surface on touch
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
      waitUntil: 'commit'
    })
    await page.getByTestId('dashboard-options-menu').click()
    await page.getByRole('button', { name: 'Days', exact: true }).click()
    await page.keyboard.press('Escape')

    const marker = page.getByTestId('annotation-marker-on-bucket-0')
    await expect(marker).toBeVisible()

    // The graph is horizontally scrollable on mobile; ensure the marker didn't
    // collapse to zero-size or slide off-screen.
    const markerBox = await marker.boundingBox()
    expect(markerBox).not.toBeNull()
    expect(markerBox!.width).toBeGreaterThan(0)
    expect(markerBox!.height).toBeGreaterThan(0)
    expect(markerBox!.x).toBeGreaterThanOrEqual(0)
    expect(markerBox!.x).toBeLessThan(390)

    // Tap the marker's x-column inside the chart plot area. The graph uses
    // closestPoint on the tap x, so a small y above the marker is enough.
    await page.touchscreen.tap(
      markerBox!.x + markerBox!.width / 2,
      Math.max(4, markerBox!.y - 60)
    )

    const tooltip = page.getByTestId('graph-tooltip')
    await expect(tooltip).toContainText(noteText)
  })
})

// Site annotations are a paid feature: available on trial and on Growth/Business
// plans, but not on Starter. The frontend enforces this by disabling the "Site
// note" option in the create modal (see annotations-modals.tsx).
async function openCreateNoteModal({
  page,
  domain
}: {
  page: Page
  domain: string
}) {
  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  const bucket = page.getByTestId('graph-dot-series-1-bucket-0')
  await bucket.hover()
  const tooltip = page.getByTestId('graph-tooltip')
  await expect(tooltip).toBeVisible()
  await bucket.click({ button: 'right' })
  await tooltip.getByRole('button', { name: 'Add note' }).click()
  await expect(
    page.getByRole('heading', { name: /^Add note for/ })
  ).toBeVisible()
}

async function seedForPlanCheck({
  page,
  request,
  plan
}: {
  page: Page
  request: APIRequestContext
  plan?: 'starter' | 'growth' | 'business'
}) {
  const user = {
    email: `owner-plan-${plan ?? 'trial'}-${randomID()}@example.com`,
    name: `Owner ${randomID()}`,
    password: 'VeryStrongVerySecret'
  }
  await register({ page, request, user })
  const { domain } = await setupSite({ page, request, user })
  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 1,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-06-29 10:00:00'
      }
    ]
  })
  if (plan) {
    await subscribeToPlan({ request, domain, plan })
  }
  return { domain, user }
}

for (const plan of ['trial', 'growth', 'business'] as const) {
  test(`user on ${plan} plan can create a site annotation`, async ({
    page,
    request
  }) => {
    const seedArgs =
      plan === 'trial'
        ? { page, request }
        : { page, request, plan }
    const { domain } = await seedForPlanCheck(seedArgs)

    await openCreateNoteModal({ page, domain })

    const noteText = `${plan}: launch marker`
    await page.getByRole('textbox', { name: 'Note' }).fill(noteText)
    await page.getByRole('radio', { name: /Site note/ }).check()
    await expect(page.getByText(/don't have enough permissions/i)).toHaveCount(
      0
    )
    await expect(
      page.getByText(/please upgrade your subscription/i)
    ).toHaveCount(0)

    const saveBtn = page.getByRole('button', { name: 'Save' })
    await expect(saveBtn).toBeEnabled()
    await saveBtn.click()

    await expect(page.getByTestId('annotation-marker-on-bucket-0')).toBeVisible()
  })
}

test('user on starter plan cannot create a site annotation', async ({
  page,
  request
}) => {
  const { domain } = await seedForPlanCheck({
    page,
    request,
    plan: 'starter'
  })

  await openCreateNoteModal({ page, domain })

  await page
    .getByRole('textbox', { name: 'Note' })
    .fill('starter: attempted site note')

  // Site note option is disabled on starter — hovering surfaces the upgrade CTA.
  await expect(page.getByRole('radio', { name: /Site note/ })).toBeDisabled()
  await page.getByText(/Site note/).hover()
  await expect(
    page.getByText(/Upgrade to Growth to make notes visible to others/i)
  ).toBeVisible()

  // Personal notes remain available and saveable.
  await expect(page.getByRole('radio', { name: /Personal note/ })).toBeChecked()
  await expect(page.getByRole('button', { name: 'Save' })).toBeEnabled()
})

test('site annotations created on trial remain usable after downgrade to starter', async ({
  page,
  request
}) => {
  const { domain } = await seedForPlanCheck({ page, request })

  const noteText = 'Trial-created site milestone'
  await createSiteAnnotationViaUI({ page, domain, note: noteText })

  // Downgrade to starter — site_annotations feature is no longer available.
  await subscribeToPlan({ request, domain, plan: 'starter' })

  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByRole('button', { name: 'Days', exact: true }).click()
  await page.keyboard.press('Escape')

  const tooltip = page.getByTestId('graph-tooltip')
  const bucket = page.getByTestId('graph-dot-series-1-bucket-0')
  const marker = page.getByTestId('annotation-marker-on-bucket-0')

  await test.step('site annotation is still visible on the graph', async () => {
    await expect(marker).toBeVisible()
    await bucket.hover()
    await expect(tooltip).toContainText(noteText)
  })

  await test.step('edit modal opens for the existing site annotation', async () => {
    await bucket.click({ button: 'right' })
    const row = tooltip.locator('div.group', { hasText: noteText })
    await row.hover()
    await row.getByRole('button', { name: 'Edit note' }).click()
    await expect(
      page.getByRole('heading', { name: /^Update note for/ })
    ).toBeVisible()
  })

  await test.step('user cannot save note text edits while type stays Site', async () => {
    // Existing site annotation is opened with type=Site preselected. The Site
    // radio is now disabled (post-downgrade) and Save stays disabled until the
    // user demotes to Personal. Hovering the Site row surfaces the upgrade CTA.
    await page
      .getByRole('textbox', { name: 'Note' })
      .fill('attempted rename while still Site')
    await expect(page.getByRole('radio', { name: /Site note/ })).toBeDisabled()
    await page.getByText(/Site note/).hover()
    await expect(
      page.getByText(/Upgrade to Growth to make notes visible to others/i)
    ).toBeVisible()
    await expect(page.getByRole('button', { name: 'Save' })).toBeDisabled()
  })

  await test.step('user can convert the site annotation to personal', async () => {
    await page.getByRole('radio', { name: /Personal note/ }).check()
    await expect(
      page.getByText(/please upgrade your subscription/i)
    ).toHaveCount(0)
    const saveBtn = page.getByRole('button', { name: 'Save' })
    await expect(saveBtn).toBeEnabled()
    // Restore the original note text so downstream assertions still find it.
    await page.getByRole('textbox', { name: 'Note' }).fill(noteText)
    await saveBtn.click()
    await expect(
      page.getByRole('heading', { name: /^Update note for/ })
    ).toBeHidden()

    await bucket.hover()
    await expect(tooltip).toContainText(noteText)
    // Attribution now reads "Personal note …" instead of the owner's name.
    await expect(tooltip).toContainText(/Personal note/)
  })

  await test.step('user can delete the (now personal) annotation', async () => {
    await bucket.click({ button: 'right' })
    const row = tooltip.locator('div.group', { hasText: noteText })
    await row.hover()
    await row.getByRole('button', { name: 'Edit note' }).click()
    await expect(
      page.getByRole('heading', { name: /^Update note for/ })
    ).toBeVisible()

    await page.getByRole('button', { name: 'Delete note' }).click()
    await expect(
      page.getByRole('heading', { name: /^Delete/ })
    ).toBeVisible()
    await page.getByRole('button', { name: 'Delete', exact: true }).click()

    await expect(marker).toBeHidden()
  })
})
