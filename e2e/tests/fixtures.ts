import type { Page, Request } from '@playwright/test'
import { expect } from '@playwright/test'
import { expectLiveViewConnected, randomID } from './test-utils.ts'

type User = {
  name: string
  email: string
  password: string
}

type EventTimestamp =
  | { minutesAgo: number }
  | { hoursAgo: number }
  | { daysAgo: number }

type Event = {
  name: string
  user_id?: number
  scroll_depth?: number
  revenue_reporting_amount?: string
  revenue_reporting_currency?: string
  pathname?: string
  hostname?: string
  referrer_source?: string
  referrer?: string
  utm_medium?: string
  utm_source?: string
  utm_campaign?: string
  utm_term?: string
  utm_content?: string
  screen_size?: string
  browser?: string
  browser_version?: string
  operating_system?: string
  operating_system_version?: string
  'meta.key'?: string[]
  'meta.value'?: string[]
  timestamp?: EventTimestamp
}

export async function register({
  page,
  request,
  user
}: {
  page: Page
  request: Request
  user: User
}) {
  await page.goto('/register')

  await expectLiveViewConnected(page)

  await expect(
    page.getByRole('button', { name: 'Start my free trial' })
  ).toBeVisible()

  await page.getByLabel('Full name').fill(user.name)
  await page.getByLabel('Email').fill(user.email)
  await page.getByLabel('Password', { exact: true }).fill(user.password)
  await page.getByLabel('Confirm password', { exact: true }).fill(user.password)
  await expect(
    page.getByRole('button', { name: 'Start my free trial' })
  ).toBeEnabled()
  await page.getByRole('button', { name: 'Start my free trial' }).click()

  await expect(
    page.getByRole('heading', { name: 'Activate your account' })
  ).toBeVisible()

  const response = await request.get('/sent-emails-api/emails.json')

  const emailData = await response.json()

  const emails = emailData.filter(
    (e) =>
      e.to[0][0] === user.name &&
      e.subject.indexOf('is your Plausible email verification code') > -1
  )

  expect(emails.length).toEqual(1)

  const [code] = emails[0].subject.split(' ')

  await page.locator('input[name=code]').fill(code)

  await page.getByRole('button', { name: 'Activate' }).click()

  await expect(
    page.getByRole('button', { name: 'Install Plausible' })
  ).toBeVisible()
}

export async function login({ page, user }: { page: Page; user: User }) {
  await page.goto('/login')

  await expect(page.getByRole('button', { name: 'Log in' })).toBeVisible()

  await page.getByLabel('Email').fill(user.email)
  await page.getByLabel('Password').fill(user.password)
  await page.getByRole('button', { name: 'Log in' }).click()

  await expect(page.getByRole('button', { name: user.name })).toBeVisible()
}

export async function logout(page: Page) {
  await page.goto('/logout')

  await expect(
    page.getByRole('heading', { name: 'Welcome to Plausible!' })
  ).toBeVisible()
}

export async function addSite({
  page,
  domain
}: {
  page: Page
  domain: string
}) {
  await page.goto('/sites/new')

  await expect(
    page.getByRole('button', { name: 'Install Plausible' })
  ).toBeVisible()

  await page.getByLabel('Domain').fill(domain)
  await page.getByLabel('Reporting timezone').selectOption('Etc/UTC')

  await page.getByRole('button', { name: 'Install Plausible' }).click()

  await expect(
    page.getByRole('button', { name: 'Verify Script installation' })
  ).toBeVisible()
}

export async function makeSitePublic({
  page,
  domain
}: {
  page: Page
  domain: string
}) {
  await page.goto(`/${domain}/settings/visibility`)

  await page
    .getByRole('form', { name: 'Make stats publicly available' })
    .getByRole('button')
    .click()

  await expect(page.locator('body')).toContainText('are now public')
}

export async function populateStats({
  request,
  domain,
  events
}: {
  request: Request
  domain: string
  events: Event[]
}) {
  const response = await request.post('/e2e-tests/stats', {
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json'
    },
    data: { domain: domain, events: events }
  })

  expect(response.ok()).toBeTruthy()
}

export async function addCustomGoal({
  page,
  domain,
  name,
  displayName,
  currency,
  // Useful when adding a goal for which there's no matching stat yet
  clickManually = true
}: {
  page: Page
  domain: string
  name: string
  displayName?: string
  currency?: string
  clickManually?: boolean
}) {
  await page.goto(`/${domain}/settings/goals`)

  await expectLiveViewConnected(page)

  await page.getByRole('button', { name: 'Add goal' }).click()
  const customEventButton = page.locator(
    'button[phx-value-goal-type="custom_events"]'
  )

  await customEventButton.click()

  if (clickManually) {
    await page.getByRole('button', { name: 'Add manually' }).click()
  }

  await expect(
    page.getByRole('heading', { name: `Add goal for ${domain}` })
  ).toBeVisible()
  // NOTE: Locating inputs by role and label does not work in this case
  // for some reason.
  const nameInput = page.locator('input[placeholder="e.g. Signup"]')
  await nameInput.fill(name)
  await page.locator(`a[data-display-value="${name}"]`).click()
  await expect(nameInput).toHaveAttribute('value', name)

  if (displayName) {
    await page
      .locator('input#custom_event_display_name_input')
      .fill(displayName)
  }

  if (currency) {
    page.locator('button[aria-labelledby="enable-revenue-tracking"]').click()
    const currencyInput = page.locator('input[id^=currency_input_]')
    await currencyInput.fill(currency)
    await page.locator(`a[phx-value-submit-value="${currency}"]`).click()
    await expect(page.locator('input[name="goal[currency]"]')).toHaveAttribute(
      'value',
      currency
    )
  }

  await page
    .locator('form[phx-submit="save-goal"]')
    .getByRole('button', { name: 'Add goal' })
    .click()

  await expect(page.locator('body')).toContainText('Goal saved successfully')
}

export async function addPageviewGoal({
  page,
  domain,
  pathname,
  displayName
}: {
  page: Page
  domain: string
  pathname: string
  displayName?: string
}) {
  await page.goto(`/${domain}/settings/goals`)

  await expectLiveViewConnected(page)

  await page.getByRole('button', { name: 'Add goal' }).click()
  const pageviewEventButton = page.locator(
    'button[phx-value-goal-type="pageviews"]'
  )

  await pageviewEventButton.click()

  await expect(
    page.getByRole('heading', { name: `Add goal for ${domain}` })
  ).toBeVisible()

  const pathnameInput = page.locator('input[id^="page_path_input"]')
  await pathnameInput.fill(pathname)
  await page.locator(`a[data-display-value="${pathname}"]`).click()
  await expect(pathnameInput).toHaveAttribute('value', pathname)
  if (displayName) {
    await page.locator('input#pageview_display_name_input').fill(displayName)
  }

  await page
    .locator('form[phx-submit="save-goal"]')
    .getByRole('button', { name: 'Add goal' })
    .click()

  await expect(page.locator('body')).toContainText('Goal saved successfully')
}

export async function addScrollDepthGoal({
  page,
  domain,
  pathname,
  displayName,
  scrollPercentage
}: {
  page: Page
  domain: string
  pathname: string
  displayName?: string
  scrollPercentage?: number
}) {
  await page.goto(`/${domain}/settings/goals`)

  await expectLiveViewConnected(page)

  await page.getByRole('button', { name: 'Add goal' }).click()
  const scrollDepthEventButton = page.locator(
    'button[phx-value-goal-type="scroll"]'
  )

  await scrollDepthEventButton.click()

  await expect(
    page.getByRole('heading', { name: `Add goal for ${domain}` })
  ).toBeVisible()

  if (scrollPercentage) {
    await page
      .locator('input[name="goal[scroll_threshold]"]')
      .fill(scrollPercentage.toString())
  }

  const pathnameInput = page.locator('input[id^="scroll_page_path_input"]')
  await pathnameInput.fill(pathname)
  await page.locator(`a[data-display-value="${pathname}"]`).click()
  await expect(pathnameInput).toHaveAttribute('value', pathname)

  if (displayName) {
    await page.locator('input#scroll_display_name_input').fill(displayName)
  }

  await page
    .locator('form[phx-submit="save-goal"]')
    .getByRole('button', { name: 'Add goal' })
    .click()

  await expect(page.locator('body')).toContainText('Goal saved successfully')
}

export async function addCustomProp({
  page,
  domain,
  name
}: {
  page: Page
  domain: string
  name: string
}) {
  await page.goto(`/${domain}/settings/properties`)

  await expectLiveViewConnected(page)

  await page.getByRole('button', { name: 'Add property' }).click()

  await expect(
    page.getByRole('heading', { name: `Add property for ${domain}` })
  ).toBeVisible()

  const propInput = page.locator('input#prop_input')
  propInput.fill(name)
  await page.locator(`a[data-display-value="${name}"]`).click()
  await expect(propInput).toHaveAttribute('value', name)

  await page
    .locator('form[phx-submit="allow-prop"]')
    .getByRole('button', { name: 'Add property' })
    .click()

  await expect(page.locator('body')).toContainText(
    'Property added successfully'
  )
}

export async function addAllCustomProps({
  page,
  domain
}: {
  page: Page
  domain: string
}) {
  await page.goto(`/${domain}/settings/properties`)

  await expectLiveViewConnected(page)

  await page.getByRole('button', { name: 'Add property' }).click()

  await expect(
    page.getByRole('heading', { name: `Add property for ${domain}` })
  ).toBeVisible()

  await page.getByText(/Click to add [0-9]+ existing properties/).click()

  await expect(page.locator('body')).toContainText(
    'Properties added successfully'
  )
}

export async function addFunnel({
  request,
  domain,
  name,
  steps
}: {
  request: Request
  domain: string
  name: string
  steps: string[]
}) {
  const response = await request.post('/e2e-tests/funnel', {
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json'
    },
    data: { domain: domain, name: name, steps: steps }
  })

  expect(response.ok()).toBeTruthy()
}
//
// export async function addFunnel({
//   page,
//   domain,
//   name,
//   steps
// }: {
//   page: Page
//   domain: string
//   name: string
//   steps: string[]
// }) {
//   await page.goto(`/${domain}/settings/funnels`)
//
//   await expectLiveViewConnected(page)
//
//   await page.getByRole('button', { name: 'Add funnel' }).click()
//
//   await page.locator('input#funnel_name').fill(name)
//
//   const addStepLink = page.getByText('Add another step')
//
//   for (let idx = 0; idx < steps.length; idx++) {
//     const step = steps[idx]
//
//     if (idx > 1) {
//       await addStepLink.click()
//     }
//     const propInput = page.locator(`input#step-${idx + 1}`)
//     await propInput.fill(step)
//     await page
//       .locator(`a[data-display-value="${step}"][phx-target="${idx + 1}"]`)
//       .click()
//     await expect(propInput).toHaveAttribute('value', step)
//   }
//
//   const addFunnelButton = page
//     .locator('form[phx-submit="save"]')
//     .getByRole('button', { name: 'Add funnel' })
//
//   await addFunnelButton.click()
//
//   await expect(addFunnelButton).toBeHidden()
//   await expect(page.locator('body')).toContainText('Funnel saved successfully')
// }

export async function setupSite({
  user,
  page,
  request
}: {
  user?: User
  page: Page
  request: Request
}): { domain: string; user: user } {
  const domain = `${randomID()}.example.com`

  if (!user) {
    const userID = randomID()

    user = {
      name: `User ${userID}`,
      email: `email-${userID}@example.com`,
      password: 'VeryStrongVerySecret'
    }

    await register({ page, request, user })
  }

  await addSite({ page, domain })

  return { domain, user }
}
