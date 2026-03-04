import { test, expect } from '@playwright/test'
import {
  setupSite,
  logout,
  makeSitePublic,
  populateStats,
  createSharedLink
} from '../fixtures.ts'

test('dashboard renders for logged in user', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })

  await page.goto('/' + domain)

  await expect(page).toHaveTitle(/Plausible/)

  await expect(page.getByRole('button', { name: domain })).toBeVisible()
})

test('dashboard renders for anonymous viewer', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await makeSitePublic({ page, domain })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })
  await logout(page)

  await page.goto('/' + domain)

  await expect(page).toHaveTitle(/Plausible/)

  await expect(page.getByRole('button', { name: domain })).toBeVisible()
})

test('dashboard renders via shared link', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })
  const link = await createSharedLink({ page, domain, name: 'public_link' })
  const passwordLink = await createSharedLink({
    page,
    domain,
    name: 'password_link',
    password: 'secret'
  })
  await logout(page)

  await test.step('public link', async () => {
    await page.goto(link)

    await expect(page.getByRole('button', { name: domain })).toBeVisible()

    await expect(page.locator('#visitors')).toHaveText('1')
  })

  await test.step('password protected link', async () => {
    await page.goto(passwordLink)

    await page.locator('input#password').fill('secret')

    await page.getByRole('button', { name: 'Continue' }).click()

    await expect(page.getByRole('button', { name: domain })).toBeVisible()

    await expect(page.locator('#visitors')).toHaveText('1')
  })
})

test('dashboard renders with imported data', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview' },
      {
        type: 'imported_visitors',
        visitors: 3,
        visits: 4,
        pageviews: 6,
        bounces: 1
      }
    ]
  })

  await page.goto('/' + domain)

  await test.step('with imported data included', async () => {
    await expect(page.locator('#visitors')).toHaveText('4')
    await expect(page.locator('#visits')).toHaveText('5')
    await expect(page.locator('#pageviews')).toHaveText('7')
    await expect(page.locator('#bounce_rate')).toHaveText('40%')
  })

  await test.step('with imported data excluded', async () => {
    await page.getByTestId('import-switch').click()

    await expect(page).toHaveURL(/with_imported=false/)

    await expect(page.locator('#visitors')).toHaveText('1')
    await expect(page.locator('#visits')).toHaveText('1')
    await expect(page.locator('#pageviews')).toHaveText('1')
    await expect(page.locator('#bounce_rate')).toHaveText('100%')
  })
})

test('tab selection user preferences are preserved across reloads', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })

  await page.goto('/' + domain)

  await page.getByRole('button', { name: 'Entry pages' }).click()

  await page.goto('/' + domain)

  let currentTab = await page.evaluate(
    (domain) => localStorage.getItem('pageTab__' + domain),
    domain
  )

  expect(currentTab).toEqual('entry-pages')

  await page.getByRole('button', { name: 'Exit pages' }).click()

  await page.goto('/' + domain)

  currentTab = await page.evaluate(
    (domain) => localStorage.getItem('pageTab__' + domain),
    domain
  )

  expect(currentTab).toEqual('exit-pages')
})

test('back navigation closes the modal', async ({ page, request, baseURL }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({
    request,
    domain,
    events: [{ name: 'pageview' }]
  })

  await page.goto('/' + domain)

  await page.getByRole('button', { name: 'Filter' }).click()

  await page.getByRole('link', { name: 'Page' }).click()

  await expect(page).toHaveURL(baseURL + '/' + domain + '/filter/page')

  await page.goBack()

  await expect(page).toHaveURL(baseURL + '/' + domain)
})
