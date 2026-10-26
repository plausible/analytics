import { test, expect, Page, Locator } from '@playwright/test'
import {
  setupSite,
  populateStats,
  addGoal,
  addFunnel,
  getFunnel,
  makeSitePublic,
  logout
} from '../fixtures'
import {
  tabButton,
  tabButtonWithDropdown,
  modal,
  dropdown
} from '../test-utils'

const getReport = (page: Page) => page.getByTestId('report-behaviours')

const column = (report: Locator, index: number) =>
  report.getByTestId(`exploration-column-${index}`)

const pick = (report: Locator, index: number, label: string) =>
  column(report, index).getByRole('button', { name: label })

async function saveFunnelAs(page: Page, name: string) {
  await getReport(page).getByTestId('funnel-builder-save').click()
  await modal(page).getByLabel('Funnel name').fill(name)
  await modal(page).getByRole('button', { name: 'Save', exact: true }).click()
}

const journeyEvents = [
  {
    user_id: 1,
    name: 'pageview',
    pathname: '/blog',
    timestamp: { minutesAgo: 60 }
  },
  {
    user_id: 1,
    name: 'pageview',
    pathname: '/pricing',
    timestamp: { minutesAgo: 59 }
  },
  { user_id: 1, name: 'Signup', timestamp: { minutesAgo: 58 } },
  {
    user_id: 2,
    name: 'pageview',
    pathname: '/blog',
    timestamp: { minutesAgo: 60 }
  },
  { user_id: 2, name: 'Signup', timestamp: { minutesAgo: 59 } },
  {
    user_id: 3,
    name: 'pageview',
    pathname: '/blog',
    timestamp: { minutesAgo: 60 }
  }
]

test('saving an explored journey as a funnel', async ({ page, request }) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: journeyEvents })

  await page.goto('/' + domain, { waitUntil: 'commit' })
  await tabButton(report, 'Explore').click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await test.step('explore a journey', async () => {
    const saveAsFunnel = report.getByTestId('exploration-save-as-funnel')

    await expect(report.getByTestId('exploration-title')).toHaveText(
      'Explore user journeys'
    )
    await expect(saveAsFunnel).toHaveCount(0)

    await pick(report, 0, '/blog').click()
    // offered once there's a starting point, savable from two steps on
    await expect(saveAsFunnel).toBeDisabled()

    await pick(report, 1, 'Signup').click()
    await expect(report.getByTestId('exploration-title')).toHaveText(
      '2-step user journey'
    )
    await expect(saveAsFunnel).toBeEnabled()
  })

  await test.step('open it in the funnel builder', async () => {
    await report.getByTestId('exploration-save-as-funnel').click()

    await expect(report.getByTestId('funnel-builder-title')).toHaveText(
      'New funnel'
    )
    await expect(page).toHaveURL(/build_funnel=new/)
    await expect(tabButton(report, 'Funnels')).toHaveAttribute(
      'data-active',
      'true'
    )

    // steps of the journey carry over
    await expect(
      report.getByTestId('exploration-column-0').getByRole('button', {
        name: '/blog'
      })
    ).toHaveAttribute('data-exploration-step', '0')

    // as in the journey, steps directly follow each other
    await expect(report.getByTestId('funnel-builder-type-strict')).toBeVisible()
    await expect(
      report.getByTestId('funnel-builder-conversion-rate')
    ).toContainText('33.3%')
  })

  await test.step('other types can still be picked', async () => {
    await report.getByTestId('funnel-builder-type-strict').click()
    await report.getByTestId('funnel-builder-type-sequential').click()
    await expect(
      report.getByTestId('funnel-builder-conversion-rate')
    ).toContainText('66.7%')

    await report.getByTestId('funnel-builder-type-sequential').click()
    await report.getByTestId('funnel-builder-type-strict').click()
    await expect(
      report.getByTestId('funnel-builder-conversion-rate')
    ).toContainText('33.3%')
  })

  await test.step('save', async () => {
    await saveFunnelAs(page, 'Blog to signup')
  })

  await test.step('lands on the saved funnel', async () => {
    await expect(page).not.toHaveURL(/build_funnel/)
    await expect(report.getByTestId('funnel-title')).toHaveText(
      'Blog to signup'
    )
    await expect(report.getByText('Strict')).toBeVisible()

    const funnel = await getFunnel({ request, domain, name: 'Blog to signup' })
    expect(funnel.funnel_type).toEqual('strict')
    expect(funnel.steps).toMatchObject([
      { id: 0, page_path: '/blog', event_name: null },
      { id: 0, event_name: 'Signup', page_path: null }
    ])
  })
})

test('building a funnel out of goals of any kind', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      ...journeyEvents,
      {
        user_id: 1,
        name: 'engagement',
        pathname: '/pricing',
        scroll_depth: 80,
        engagement_time: 10000,
        timestamp: { minutesAgo: 59 }
      },
      {
        user_id: 1,
        name: 'Purchase',
        revenue_reporting_amount: '10',
        revenue_reporting_currency: 'USD',
        timestamp: { minutesAgo: 57 }
      }
    ]
  })

  await addGoal({
    request,
    domain,
    params: {
      page_path: '/pricing',
      scroll_threshold: 50,
      display_name: 'Read pricing'
    }
  })
  await addGoal({
    request,
    domain,
    params: { event_name: 'Purchase', currency: 'USD' }
  })

  await page.goto(`/${domain}?build_funnel=new`, { waitUntil: 'commit' })
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('funnel-builder-title')).toHaveText(
    'New funnel'
  )
  await expect(pick(report, 0, '/blog')).toBeVisible()

  // the builder survives a refresh, with suggestions loaded again
  await page.reload({ waitUntil: 'commit' })
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('funnel-builder-title')).toHaveText(
    'New funnel'
  )

  await pick(report, 0, '/blog').click()
  await pick(report, 1, 'Read pricing').click()
  await pick(report, 2, 'Purchase').click()

  await expect(
    report.getByTestId('funnel-builder-conversion-rate')
  ).toContainText('33.3%')

  await saveFunnelAs(page, 'Blog to purchase')

  await expect(report.getByTestId('funnel-title')).toHaveText(
    'Blog to purchase'
  )

  const funnel = await getFunnel({ request, domain, name: 'Blog to purchase' })
  expect(funnel.steps).toMatchObject([
    { id: 0, page_path: '/blog' },
    { display_name: 'Read pricing', scroll_threshold: 50 },
    { event_name: 'Purchase', currency: 'USD' }
  ])
  expect(funnel.steps[1].id).toBeGreaterThan(0)
  expect(funnel.steps[2].id).toBeGreaterThan(0)
})

test('editing and deleting a saved funnel', async ({ page, request }) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: journeyEvents })

  await addFunnel({
    request,
    domain,
    name: 'Blog funnel',
    steps: [{ page_path: '/blog' }, { event_name: 'Signup' }]
  })

  const { id } = await getFunnel({ request, domain, name: 'Blog funnel' })

  await page.goto('/' + domain, { waitUntil: 'commit' })
  await tabButtonWithDropdown(report, 'Funnels').click()
  await dropdown(report).getByRole('button', { name: 'Blog funnel' }).click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()
  await expect(report.getByTestId('funnel-title')).toHaveText('Blog funnel')

  await test.step('edit steps in place', async () => {
    await report.getByTestId('funnel-edit').click()

    await expect(page).toHaveURL(new RegExp(`build_funnel=${id}`))
    await expect(
      tabButton(tabButtonWithDropdown(report, 'Funnels'), 'Funnels')
    ).toHaveAttribute('data-active', 'true')
    await expect(report.getByTestId('funnel-builder-title')).toHaveText(
      'Editing “Blog funnel”'
    )

    // deselecting the second step lets a different one be picked instead
    await pick(report, 1, 'Signup').click()
    await pick(report, 1, '/pricing').click()

    await report.getByTestId('funnel-builder-save').click()
    await expect(modal(page).getByLabel('Funnel name')).toHaveValue(
      'Blog funnel'
    )
    await modal(page).getByLabel('Funnel name').fill('Blog to pricing')
    await modal(page).getByRole('button', { name: 'Save', exact: true }).click()

    await expect(report.getByTestId('funnel-title')).toHaveText(
      'Blog to pricing'
    )

    const funnel = await getFunnel({ request, domain, name: 'Blog to pricing' })
    expect(funnel.id).toEqual(id)
    expect(funnel.steps).toMatchObject([
      { page_path: '/blog' },
      { page_path: '/pricing' }
    ])
  })

  await test.step('cancelling an edit leaves the funnel untouched', async () => {
    await report.getByTestId('funnel-edit').click()
    await report.getByTestId('funnel-builder-cancel').click()

    await expect(page).not.toHaveURL(/build_funnel/)
    await expect(report.getByTestId('funnel-title')).toHaveText(
      'Blog to pricing'
    )
  })

  await test.step('delete', async () => {
    await tabButtonWithDropdown(report, 'Funnels').click()
    await dropdown(report)
      .getByRole('button', { name: 'Blog to pricing' })
      .click()
    await report.getByTestId('funnel-delete').click()
    await modal(page).getByRole('button', { name: 'Delete' }).click()

    await expect(report.getByTestId('funnel-title')).toBeHidden()
    await expect(
      report.getByRole('link', { name: /Build a funnel/ })
    ).toBeVisible()
  })
})

test('building a new funnel from the funnels tab', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: journeyEvents })

  await addFunnel({
    request,
    domain,
    name: 'Blog funnel',
    steps: [{ page_path: '/blog' }, { event_name: 'Signup' }]
  })

  const funnelsTab = tabButton(
    tabButtonWithDropdown(report, 'Funnels'),
    'Funnels'
  )

  await page.goto('/' + domain, { waitUntil: 'commit' })
  await tabButtonWithDropdown(report, 'Funnels').click()
  await dropdown(report).getByRole('button', { name: '+ New funnel' }).click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('funnel-builder-title')).toHaveText(
    'New funnel'
  )
  await expect(funnelsTab).toHaveAttribute('data-active', 'true')
  await expect(tabButton(report, 'Explore')).not.toHaveAttribute(
    'data-active',
    'true'
  )
  await expect(pick(report, 0, '/blog')).toBeVisible()

  // the builder survives a refresh, with suggestions loaded again
  await page.reload({ waitUntil: 'commit' })
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('funnel-builder-title')).toHaveText(
    'New funnel'
  )
  await expect(funnelsTab).toHaveAttribute('data-active', 'true')
  await expect(pick(report, 0, '/blog')).toBeVisible()

  await report.getByTestId('funnel-builder-cancel').click()

  await expect(page).not.toHaveURL(/build_funnel/)
  await expect(funnelsTab).toHaveAttribute('data-active', 'true')
  await expect(report.getByTestId('funnel-title')).toHaveText('Blog funnel')
})

test('failing to load steps to pick from', async ({ page, request }) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: journeyEvents })

  await page.route(/\/funnels\/candidates/, (route) =>
    route.fulfill({ status: 500, body: '{}' })
  )

  await page.goto(`/${domain}?build_funnel=new`, { waitUntil: 'commit' })
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  const error = column(report, 0).getByTestId('exploration-column-error')
  await expect(error).toHaveText(/Steps could not be loaded/)

  await page.unroute(/\/funnels\/candidates/)
  await error.getByRole('button', { name: 'try again' }).click()

  await expect(error).toBeHidden()
  await expect(pick(report, 0, '/blog')).toBeVisible()
})

test('typing a page that has no visits yet as a step', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 1,
        name: 'pageview',
        pathname: '/signup',
        timestamp: { minutesAgo: 5 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })
  await tabButton(report, 'Funnels').click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()
  await report.getByRole('link', { name: /Build a funnel/ }).click()

  await expect(report.getByTestId('funnel-builder-title')).toHaveText(
    'New funnel'
  )

  await pick(report, 0, '/signup').click()

  // nothing else was visited, but a page can still be typed in
  await column(report, 1).getByTestId('search-input').fill('/login')
  await pick(report, 1, '/login').click()

  await expect(
    report.getByTestId('funnel-builder-conversion-rate')
  ).toContainText('0%')
  await expect(
    report.getByTestId('funnel-builder-type-sequential')
  ).toBeVisible()

  await saveFunnelAs(page, 'Signup to login')

  await expect(report.getByTestId('funnel-title')).toHaveText('Signup to login')

  const funnel = await getFunnel({ request, domain, name: 'Signup to login' })
  expect(funnel.funnel_type).toEqual('sequential')
  expect(funnel.steps).toMatchObject([
    { id: 0, page_path: '/signup', event_name: null },
    { id: 0, page_path: '/login', event_name: null }
  ])
})

test('funnels cannot be built from a public dashboard', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })
  await populateStats({ request, domain, events: journeyEvents })
  await makeSitePublic({ page, domain })
  await logout(page)

  await page.goto(`/${domain}?build_funnel=new`, { waitUntil: 'commit' })
  await tabButton(report, 'Explore').click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )
  await expect(report.getByTestId('funnel-builder')).toHaveCount(0)

  await pick(report, 0, '/blog').click()
  await pick(report, 1, 'Signup').click()
  await expect(report.getByTestId('exploration-title')).toHaveText(
    '2-step user journey'
  )
  await expect(report.getByTestId('exploration-save-as-funnel')).toHaveCount(0)
})

test.describe('suggestion counts while building a funnel', () => {
  // A: /blog → /pricing → Signup
  // B: /blog → Signup
  // C: /pricing
  // D: /blog
  // E: Signup
  const countEvents = [
    ...['/blog', '/pricing'].map((pathname, i) => ({
      user_id: 1,
      name: 'pageview',
      pathname,
      timestamp: { minutesAgo: 60 - i }
    })),
    { user_id: 1, name: 'Signup', timestamp: { minutesAgo: 58 } },
    {
      user_id: 2,
      name: 'pageview',
      pathname: '/blog',
      timestamp: { minutesAgo: 60 }
    },
    { user_id: 2, name: 'Signup', timestamp: { minutesAgo: 59 } },
    {
      user_id: 3,
      name: 'pageview',
      pathname: '/pricing',
      timestamp: { minutesAgo: 60 }
    },
    {
      user_id: 4,
      name: 'pageview',
      pathname: '/blog',
      timestamp: { minutesAgo: 60 }
    },
    { user_id: 5, name: 'Signup', timestamp: { minutesAgo: 60 } }
  ]

  const count = (report: Locator, index: number, label: string) =>
    pick(report, index, label).getByTestId('metric-value')

  async function expectNoSuggestionCounts(report: Locator, index: number) {
    const rows = column(report, index).getByTestId('exploration-row')
    await expect(rows.first()).toBeVisible()
    await expect(column(report, index).getByTestId('metric-value')).toHaveCount(
      0
    )
    await expect(column(report, index).getByTestId('metric-bar')).toHaveCount(0)
  }

  async function openNewFunnel(page: Page, domain: string) {
    await page.goto(`/${domain}?build_funnel=new`, { waitUntil: 'commit' })
    await getReport(page).getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(
      getReport(page).getByTestId('funnel-builder-title')
    ).toHaveText('New funnel')
  }

  test('only the first step and selected steps show counts', async ({
    page,
    request
  }) => {
    const report = getReport(page)
    const { domain } = await setupSite({ page, request })
    await populateStats({ request, domain, events: countEvents })
    await openNewFunnel(page, domain)

    await test.step('the first step shows how many visitors did each', async () => {
      await expect(count(report, 0, '/blog')).toHaveText('3')
      await expect(count(report, 0, 'Signup')).toHaveText('3')
      await expect(count(report, 0, '/pricing')).toHaveText('2')
    })

    await test.step('suggestions for the second step have no counts', async () => {
      await pick(report, 0, '/blog').click()
      await expect(pick(report, 1, 'Signup')).toBeVisible()
      await expect(pick(report, 1, '/pricing')).toBeVisible()
      await expectNoSuggestionCounts(report, 1)
    })

    await test.step('a selected step shows its funnel count', async () => {
      await pick(report, 1, 'Signup').click()
      await expect(count(report, 1, 'Signup')).toHaveText('2')
      await expect(
        report.getByTestId('funnel-builder-conversion-rate')
      ).toContainText('66.7%')
    })

    await test.step('switching type updates selected counts', async () => {
      await report.getByTestId('funnel-builder-type-sequential').click()
      await report.getByTestId('funnel-builder-type-strict').click()
      await expect(count(report, 1, 'Signup')).toHaveText('1')
      await expect(
        report.getByTestId('funnel-builder-conversion-rate')
      ).toContainText('33.3%')
    })

    await test.step('deselecting brings back suggestions without counts', async () => {
      await pick(report, 1, 'Signup').click()
      await expect(pick(report, 1, '/pricing')).toBeVisible()
      await expectNoSuggestionCounts(report, 1)
    })
  })

  test('editing a saved funnel', async ({ page, request }) => {
    const report = getReport(page)
    const { domain } = await setupSite({ page, request })
    await populateStats({ request, domain, events: countEvents })

    await addFunnel({
      request,
      domain,
      name: 'Blog to signup',
      steps: [{ page_path: '/blog' }, { event_name: 'Signup' }]
    })
    const { id } = await getFunnel({ request, domain, name: 'Blog to signup' })

    await page.goto(`/${domain}?build_funnel=${id}`, { waitUntil: 'commit' })
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()

    await expect(count(report, 0, '/blog')).toHaveText('3')
    await expect(count(report, 1, 'Signup')).toHaveText('2')

    await pick(report, 1, 'Signup').click()
    await expect(pick(report, 1, '/pricing')).toBeVisible()
    await expectNoSuggestionCounts(report, 1)
  })

  test('typed pages have no count until picked', async ({ page, request }) => {
    const report = getReport(page)
    const { domain } = await setupSite({ page, request })
    await populateStats({ request, domain, events: countEvents })
    await openNewFunnel(page, domain)

    await pick(report, 0, '/blog').click()
    await column(report, 1).getByTestId('search-input').fill('/login')
    await expect(pick(report, 1, '/login')).toBeVisible()
    await expectNoSuggestionCounts(report, 1)

    await pick(report, 1, '/login').click()
    await expect(count(report, 1, '/login')).toHaveText('0')
  })
})
