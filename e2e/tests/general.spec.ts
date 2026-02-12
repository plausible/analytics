import { test, expect } from '@playwright/test'
import {
  setupSite,
  logout,
  makeSitePublic,
  populateStats,
  addCustomGoal,
  addPageviewGoal,
  addScrollDepthGoal
} from './fixtures.ts'

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

test('filter is applied', async ({ page, request, baseURL }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', pathname: '/page1' },
      { name: 'pageview', pathname: '/page2' },
      { name: 'pageview', pathname: '/page3' },
      { name: 'pageview', pathname: '/other' }
    ]
  })

  await page.goto('/' + domain)

  await expect(page.getByRole('link', { name: 'Page' })).toBeHidden()

  await page.getByRole('button', { name: 'Filter' }).click()

  await expect(page.getByRole('link', { name: 'Page' })).toHaveCount(1)

  await page.getByRole('link', { name: 'Page' }).click()

  await expect(page).toHaveURL(baseURL + '/' + domain + '/filter/page')

  await expect(
    page.getByRole('heading', { name: 'Filter by Page' })
  ).toBeVisible()

  await expect(
    page.getByRole('button', { name: 'Apply filter', disabled: true })
  ).toHaveCount(1)

  await page.getByPlaceholder('Select a Page').click()

  await expect(
    page.getByRole('button', { name: 'Apply filter', disabled: true })
  ).toHaveCount(1)

  await expect(
    page.getByRole('listitem').filter({ hasText: '/page1' })
  ).toBeVisible()

  await expect(
    page.getByRole('listitem').filter({ hasText: '/page2' })
  ).toBeVisible()

  await expect(
    page.getByRole('listitem').filter({ hasText: '/page3' })
  ).toBeVisible()

  await expect(
    page.getByRole('listitem').filter({ hasText: '/other' })
  ).toBeVisible()

  await page.getByPlaceholder('Select a Page').fill('pag')

  await expect(
    page.getByRole('listitem').filter({ hasText: '/page1' })
  ).toBeVisible()

  await expect(
    page.getByRole('listitem').filter({ hasText: '/page2' })
  ).toBeVisible()

  await expect(
    page.getByRole('listitem').filter({ hasText: '/page3' })
  ).toBeVisible()

  await expect(
    page.getByRole('listitem').filter({ hasText: '/other' })
  ).toBeHidden()

  await page.getByRole('listitem').filter({ hasText: '/page1' }).click()

  await expect(
    page.getByRole('button', { name: 'Apply filter', disabled: false })
  ).toHaveCount(1)

  await page.getByRole('button', { name: 'Apply filter' }).click()

  await expect(page).toHaveURL(baseURL + '/' + domain + '?f=is,page,/page1')

  await expect(
    page.getByRole('link', { name: 'Page is /page1' })
  ).toHaveAttribute('title', 'Edit filter: Page is /page1')
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

test('goals are rendered', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/page1',
        timestamp: { minutesAgo: 60 }
      },
      {
        user_id: 123,
        name: 'engagement',
        pathname: '/page1',
        scroll_depth: 80,
        timestamp: { minutesAgo: 59 }
      },
      {
        user_id: 123,
        name: 'purchase',
        pathname: '/buy',
        revenue_reporting_amount: '23',
        revenue_reporting_currency: 'EUR',
        timestamp: { minutesAgo: 59 }
      },
      { user_id: 123, name: 'add_site', timestamp: { minutesAgo: 50 } }
    ]
  })

  await addCustomGoal({
    page,
    domain,
    name: 'add_site',
    displayName: 'Add a site'
  })

  await addCustomGoal({
    page,
    domain,
    name: 'purchase',
    currency: 'EUR'
  })

  await addPageviewGoal({
    page,
    domain,
    pathname: '/page1'
  })

  await addScrollDepthGoal({
    page,
    domain,
    pathname: '/page1',
    scrollPercentage: 75
  })

  await page.goto('/' + domain)

  await expect(page.getByRole('button', { name: domain })).toBeVisible()
  // To ensure lazy loading of behaviours is triggered
  page.getByRole('button', { name: 'Goals' }).scrollIntoViewIfNeeded()
  await expect(page.getByRole('link', { name: 'Add a site' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Visit /page1' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'purchase' })).toBeVisible()
  await expect(
    page.getByRole('link', { name: 'Scroll 75% on /page1' })
  ).toBeVisible()
})
