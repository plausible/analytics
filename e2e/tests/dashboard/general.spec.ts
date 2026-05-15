import { test, expect } from '@playwright/test'
import {
  setupSite,
  logout,
  makeSitePublic,
  populateStats,
  createSharedLink
} from '../fixtures'

test('dashboard renders for logged in user', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await expect(page).toHaveTitle(/Plausible/)

  await expect(page.getByRole('button', { name: domain })).toBeVisible()
})

test('dashboard renders for anonymous viewer', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await makeSitePublic({ page, domain })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })
  await logout(page)

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await expect(page).toHaveTitle(/Plausible/)

  await expect(page.getByTestId('site-switcher-static')).toContainText(domain)
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
    await page.goto(link, { waitUntil: 'commit' })

    await expect(page.getByTestId('site-switcher-static')).toContainText(domain)

    await expect(page.locator('#visitors')).toHaveText('1')
  })

  await test.step('password protected link', async () => {
    await page.goto(passwordLink, { waitUntil: 'commit' })

    await page.locator('input#password').fill('secret')

    await page.getByRole('button', { name: 'Continue' }).click()

    await expect(page.getByTestId('site-switcher-static')).toContainText(domain)

    await expect(page.locator('#visitors')).toHaveText('1')
  })
})

test('site switcher is not shown when viewing without being logged in', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })
  await makeSitePublic({ page, domain })
  await populateStats({ request, domain, events: [{ name: 'pageview' }] })
  await logout(page)

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const siteSwitcherStatic = page.getByTestId('site-switcher-static')
  await expect(siteSwitcherStatic).toContainText(domain)
  await expect(siteSwitcherStatic).not.toHaveRole('button')

  await siteSwitcherStatic.click()
  await expect(page.getByTestId('sitemenu')).not.toBeVisible()
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

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await test.step('with imported data included', async () => {
    await expect(page.locator('#visitors')).toHaveText('4')
    await expect(page.locator('#visits')).toHaveText('5')
    await expect(page.locator('#pageviews')).toHaveText('7')
    await expect(page.locator('#bounce_rate')).toHaveText('40%')
  })

  await test.step('with imported data excluded', async () => {
    await page.getByTestId('dashboard-options-menu').click()
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

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await page.getByRole('button', { name: 'Entry pages' }).click()

  await page.goto('/' + domain, { waitUntil: 'commit' })

  let currentTab = await page.evaluate(
    (domain) => localStorage.getItem('pageTab__' + domain),
    domain
  )

  expect(currentTab).toEqual('entry-pages')

  await page.getByRole('button', { name: 'Exit pages' }).click()

  await page.goto('/' + domain, { waitUntil: 'commit' })

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

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await page.getByRole('button', { name: 'Filter' }).click()

  await page.getByRole('link', { name: 'Page' }).click()

  await expect(page).toHaveURL(baseURL + '/' + domain + '/filter/page')

  await page.goBack()

  await expect(page).toHaveURL(baseURL + '/' + domain)
})
