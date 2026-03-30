import { test, expect, Page } from '@playwright/test'
import {
  setupSite,
  populateStats,
  addGoal,
  addCustomGoal,
  addPageviewGoal,
  addScrollDepthGoal,
  addAllCustomProps,
  addFunnel
} from '../fixtures'
import {
  tabButton,
  expectHeaders,
  expectRows,
  rowLink,
  expectMetricValues,
  dropdown,
  detailsLink,
  modal,
  closeModalButton,
  searchInput
} from '../test-utils'

const getReport = (page: Page) => page.getByTestId('report-behaviours')

test('special goals', async ({ page, request }) => {
  const report = getReport(page)
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
        name: 'Form: Submission',
        'meta.key': ['path'],
        'meta.value': ['/form-action/path'],
        timestamp: { minutesAgo: 50 }
      },
      {
        user_id: 123,
        name: '404',
        'meta.key': ['path'],
        'meta.value': ['/wrong-path'],
        timestamp: { minutesAgo: 45 }
      },
      {
        user_id: 123,
        name: 'Outbound Link: Click',
        'meta.key': ['url'],
        'meta.value': ['https://example.com/link'],
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 123,
        name: 'Cloaked Link: Click',
        'meta.key': ['url'],
        'meta.value': ['https://example.com/cloaked-link'],
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 123,
        name: 'File Download',
        'meta.key': ['url'],
        'meta.value': ['https://example.com/file.zip'],
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 123,
        name: 'WP Search Queries',
        'meta.key': ['search_query'],
        'meta.value': ['some query'],
        timestamp: { minutesAgo: 25 }
      },
      {
        user_id: 123,
        name: 'WP Form Completions',
        'meta.key': ['path'],
        'meta.value': ['/some/path'],
        timestamp: { minutesAgo: 20 }
      },
      {
        user_id: 124,
        name: 'pageview',
        pathname: '/page1',
        timestamp: { minutesAgo: 60 }
      },
      {
        user_id: 124,
        name: 'Form: Submission',
        'meta.key': ['path'],
        'meta.value': ['/form-action/another-path'],
        timestamp: { minutesAgo: 50 }
      },
      {
        user_id: 124,
        name: '404',
        'meta.key': ['path'],
        'meta.value': ['/another-wrong-path'],
        timestamp: { minutesAgo: 45 }
      },
      {
        user_id: 124,
        name: 'Outbound Link: Click',
        'meta.key': ['url'],
        'meta.value': ['https://example.com/another-link'],
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 124,
        name: 'Cloaked Link: Click',
        'meta.key': ['url'],
        'meta.value': ['https://example.com/another-cloaked-link'],
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 124,
        name: 'File Download',
        'meta.key': ['url'],
        'meta.value': ['https://example.com/another-file.zip'],
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 124,
        name: 'WP Search Queries',
        'meta.key': ['search_query'],
        'meta.value': ['another query'],
        timestamp: { minutesAgo: 25 }
      },
      {
        user_id: 124,
        name: 'WP Form Completions',
        'meta.key': ['path'],
        'meta.value': ['/another/path'],
        timestamp: { minutesAgo: 20 }
      }
    ]
  })

  await addGoal({ request, domain, params: { event_name: 'Form: Submission' } })
  await addGoal({ request, domain, params: { event_name: '404' } })
  await addGoal({
    request,
    domain,
    params: { event_name: 'Outbound Link: Click' }
  })
  await addGoal({
    request,
    domain,
    params: { event_name: 'Cloaked Link: Click' }
  })
  await addGoal({
    request,
    domain,
    params: { event_name: 'File Download' }
  })
  await addGoal({
    request,
    domain,
    params: { event_name: 'WP Search Queries' }
  })
  await addGoal({
    request,
    domain,
    params: { event_name: 'WP Form Completions' }
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const goalsTabButton = tabButton(report, 'Goals')

  await goalsTabButton.scrollIntoViewIfNeeded()
  await expect(goalsTabButton).toHaveAttribute('data-active', 'true')

  await expectHeaders(report, ['Goal', 'Uniques', 'Total', 'CR'])

  await expectMetricValues(report, 'Form: Submission', ['2', '2', '100%'])
  await expectMetricValues(report, '404', ['2', '2', '100%'])
  await expectMetricValues(report, 'Outbound Link: Click', ['2', '2', '100%'])
  await expectMetricValues(report, 'Cloaked Link: Click', ['2', '2', '100%'])
  await expectMetricValues(report, 'File Download', ['2', '2', '100%'])
  await expectMetricValues(report, 'WP Search Queries', ['2', '2', '100%'])
  await expectMetricValues(report, 'WP Form Completions', ['2', '2', '100%'])

  await test.step('Form: Submission goal is treated as a special goal', async () => {
    await rowLink(report, 'Form: Submission').click()

    await expect(tabButton(report, 'Form actions')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['path', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, '/form-action/path', ['1', '1', '50%'])
    await expectMetricValues(report, '/form-action/another-path', [
      '1',
      '1',
      '50%'
    ])
  })

  await page
    .getByRole('button', {
      name: 'Remove filter: Goal is Form: Submission'
    })
    .click()

  await goalsTabButton.click()

  await test.step('404 goal is treated as a special goal', async () => {
    await rowLink(report, '404').click()

    await expect(tabButton(report, '404 Pages')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['path', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, '/wrong-path', ['1', '1', '50%'])
    await expectMetricValues(report, '/another-wrong-path', ['1', '1', '50%'])
  })

  await page
    .getByRole('button', {
      name: 'Remove filter: Goal is 404'
    })
    .click()

  await goalsTabButton.click()

  await test.step('Outbound Link: Click goal is treated as a special goal', async () => {
    await rowLink(report, 'Outbound Link: Click').click()

    await expect(tabButton(report, 'Outbound Links')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['url', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, 'https://example.com/link', [
      '1',
      '1',
      '50%'
    ])
    await expectMetricValues(report, 'https://example.com/another-link', [
      '1',
      '1',
      '50%'
    ])
  })

  await page
    .getByRole('button', {
      name: 'Remove filter: Goal is Outbound Link: Click'
    })
    .click()

  await goalsTabButton.click()

  await test.step('Cloaked Link: Click goal is treated as a special goal', async () => {
    await rowLink(report, 'Cloaked Link: Click').click()

    await expect(tabButton(report, 'Cloaked Links')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['url', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, 'https://example.com/cloaked-link', [
      '1',
      '1',
      '50%'
    ])
    await expectMetricValues(
      report,
      'https://example.com/another-cloaked-link',
      ['1', '1', '50%']
    )
  })

  await page
    .getByRole('button', {
      name: 'Remove filter: Goal is Cloaked Link: Click'
    })
    .click()

  await goalsTabButton.click()

  await test.step('File Download goal is treated as a special goal', async () => {
    await rowLink(report, 'File Download').click()

    await expect(tabButton(report, 'File Downloads')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['url', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, 'https://example.com/file.zip', [
      '1',
      '1',
      '50%'
    ])
    await expectMetricValues(report, 'https://example.com/another-file.zip', [
      '1',
      '1',
      '50%'
    ])
  })

  await page
    .getByRole('button', {
      name: 'Remove filter: Goal is File Download'
    })
    .click()

  await goalsTabButton.click()

  await test.step('WP Search Queries goal is treated as a special goal', async () => {
    await rowLink(report, 'WP Search Queries').click()

    await expect(tabButton(report, 'WordPress Search Queries')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['search_query', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, 'some query', ['1', '1', '50%'])
    await expectMetricValues(report, 'another query', ['1', '1', '50%'])
  })

  await page
    .getByRole('button', {
      name: 'Remove filter: Goal is WP Search Queries'
    })
    .click()

  await goalsTabButton.click()

  await test.step('WP Form Completions goal is treated as a special goal', async () => {
    await rowLink(report, 'WP Form Completions').click()

    await expect(
      tabButton(report, 'WordPress Form Completions')
    ).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['path', 'Visitors', 'Events', 'CR'])

    await expectMetricValues(report, '/some/path', ['1', '1', '50%'])
    await expectMetricValues(report, '/another/path', ['1', '1', '50%'])
  })
})

test('goals breakdown', async ({ page, request }) => {
  const report = getReport(page)
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
        user_id: 124,
        name: 'pageview',
        pathname: '/page1',
        timestamp: { minutesAgo: 60 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/page1',
        timestamp: { minutesAgo: 60 }
      },
      {
        user_id: 126,
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
        user_id: 124,
        name: 'engagement',
        pathname: '/page1',
        scroll_depth: 80,
        timestamp: { minutesAgo: 59 }
      },
      {
        user_id: 125,
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
      { user_id: 124, name: 'add_site', timestamp: { minutesAgo: 50 } },
      { user_id: 125, name: 'add_site', timestamp: { minutesAgo: 50 } }
    ]
  })

  await addCustomGoal({
    page,
    domain,
    name: 'add_site',
    displayName: 'Add a site'
  })
  await addCustomGoal({ page, domain, name: 'purchase', currency: 'EUR' })
  await addPageviewGoal({ page, domain, pathname: '/page1' })
  await addScrollDepthGoal({
    page,
    domain,
    pathname: '/page1',
    scrollPercentage: 75
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const goalsTabButton = tabButton(report, 'Goals')

  await test.step('listing all goals', async () => {
    await goalsTabButton.scrollIntoViewIfNeeded()
    await expect(goalsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, [
      'Goal',
      'Uniques',
      'Total',
      'CR',
      'Revenue',
      'Average'
    ])

    await expectRows(report, [
      'Visit /page1',
      'Scroll 75% on /page1',
      'Add a site',
      'purchase'
    ])
    await expectMetricValues(report, 'Visit /page1', [
      '4',
      '4',
      '100%',
      '-',
      '-'
    ])
    await expectMetricValues(report, 'Scroll 75% on /page1', [
      '3',
      '-',
      '75%',
      '-',
      '-'
    ])
    await expectMetricValues(report, 'Add a site', ['2', '2', '50%', '-', '-'])
    await expectMetricValues(report, 'purchase', [
      '1',
      '1',
      '25%',
      '€23.0',
      '€23.0'
    ])
  })

  await test.step('goals modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Goal conversions' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Goal',
      /Uniques/,
      /Total/,
      /CR/,
      /Average/,
      /Revenue/
    ])

    await expectRows(modal(page), [
      'Visit /page1',
      'Scroll 75% on /page1',
      'Add a site',
      'purchase'
    ])

    await expectMetricValues(modal(page), 'Visit /page1', [
      '4',
      '4',
      '100%',
      '-',
      '-'
    ])

    await closeModalButton(page).click()
  })

  await test.step('listing goals without revenue', async () => {
    await page.goto('/' + domain + '?f=has_not_done,goal,purchase', {
      waitUntil: 'commit'
    })

    await goalsTabButton.scrollIntoViewIfNeeded()
    await expect(goalsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Goal', 'Uniques', 'Total', 'CR'])

    await expectRows(report, [
      'Visit /page1',
      'Add a site',
      'Scroll 75% on /page1'
    ])

    await expectMetricValues(report, 'Visit /page1', ['3', '3', '100%'])
    await expectMetricValues(report, 'Add a site', ['2', '2', '66.7%'])
    await expectMetricValues(report, 'Scroll 75% on /page1', [
      '2',
      '-',
      '66.7%'
    ])
  })

  await test.step('goals modal without revenue', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Goal conversions' })
    ).toBeVisible()

    await expectHeaders(modal(page), ['Goal', /Uniques/, /Total/, /CR/])

    await expectRows(modal(page), [
      'Visit /page1',
      'Add a site',
      'Scroll 75% on /page1'
    ])

    await expectMetricValues(modal(page), 'Visit /page1', ['3', '3', '100%'])

    await closeModalButton(page).click()
  })
})

test('props breakdown', async ({ page, request }) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        name: 'pageview',
        pathname: '/page',
        'meta.key': [
          'logged_in',
          'browser_language',
          'prop3',
          'prop4',
          'prop5',
          'prop6',
          'prop7',
          'prop8',
          'prop9',
          'prop10',
          'prop11'
        ],
        'meta.value': [
          'false',
          'en_US',
          'val3',
          'val4',
          'val5',
          'val6',
          'val7',
          'val8',
          'val9',
          'val10',
          'val11'
        ]
      },
      {
        name: 'pageview',
        pathname: '/page',
        'meta.key': ['logged_in', 'browser_language'],
        'meta.value': ['false', 'en_US']
      },
      {
        name: 'pageview',
        pathname: '/page',
        'meta.key': ['logged_in', 'browser_language'],
        'meta.value': ['true', 'es']
      }
    ]
  })

  await addPageviewGoal({ page, domain, pathname: '/page' })

  await addAllCustomProps({ page, domain })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const propsTabButton = tabButton(report, 'Properties')

  await test.step('listing props', async () => {
    await propsTabButton.scrollIntoViewIfNeeded()
    await propsTabButton.click()
    await dropdown(report)
      .getByRole('button', { name: 'browser_language' })
      .click()

    await expect(propsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['browser_language', 'Visitors', 'Events', '%'])

    await expectRows(report, ['en_US', 'es'])

    await expectMetricValues(report, 'en_US', ['2', '2', '66.7%'])
    await expectMetricValues(report, 'es', ['1', '1', '33.3%'])
  })

  await test.step('loading more', async () => {
    await propsTabButton.click()
    const showMoreButton = dropdown(report).getByRole('button', {
      name: 'Show 1 more'
    })
    await showMoreButton.click()
    await expect(showMoreButton).toBeHidden()
    await expect(dropdown(report).getByRole('button')).toHaveCount(11)
  })

  await test.step('searching', async () => {
    await searchInput(report).fill('prop1')
    await expect(dropdown(report).getByRole('button')).toHaveCount(2)
  })

  await test.step('props modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Custom property breakdown' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'browser_language',
      /Visitors/,
      /Events/,
      /%/
    ])

    await expectRows(modal(page), ['en_US', 'es'])

    await expectMetricValues(modal(page), 'en_US', ['2', '2', '66.7%'])

    await closeModalButton(page).click()
  })

  await test.step('clicking goal opens props', async () => {
    const goalsTabButton = tabButton(report, 'Goals')
    goalsTabButton.click()

    await expect(goalsTabButton).toHaveAttribute('data-active', 'true')

    await rowLink(report, 'Visit /page').click()

    await expect(propsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, [
      'browser_language',
      'Visitors',
      'Events',
      'CR'
    ])

    await expectRows(report, ['en_US', 'es'])

    await expectMetricValues(report, 'en_US', ['2', '2', '66.7%'])
    await expectMetricValues(report, 'es', ['1', '1', '33.3%'])
  })
})

test('funnels', async ({ page, request }) => {
  const report = getReport(page)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/products',
        timestamp: { minutesAgo: 60 }
      },
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/cart',
        timestamp: { minutesAgo: 55 }
      },
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/checkout',
        timestamp: { minutesAgo: 50 }
      },
      {
        user_id: 124,
        name: 'pageview',
        pathname: '/products',
        timestamp: { minutesAgo: 55 }
      },
      {
        user_id: 124,
        name: 'pageview',
        pathname: '/cart',
        timestamp: { minutesAgo: 50 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/products',
        timestamp: { minutesAgo: 50 }
      }
    ]
  })

  await addPageviewGoal({ page, domain, pathname: '/products' })
  await addPageviewGoal({ page, domain, pathname: '/cart' })
  await addPageviewGoal({ page, domain, pathname: '/checkout' })

  for (let idx = 0; idx < 11; idx++) {
    await addFunnel({
      request,
      domain,
      name: `Shopping ${idx + 1} Funnel`,
      steps: ['Visit /products', 'Visit /cart', 'Visit /checkout']
    })
  }

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const funnelsTabButton = tabButton(report, 'Funnels')

  await test.step('rendering funnels', async () => {
    await funnelsTabButton.scrollIntoViewIfNeeded()
    await funnelsTabButton.click()
    await dropdown(report)
      .getByRole('button', { name: 'Shopping 11 Funnel' })
      .click()

    await expect(funnelsTabButton).toHaveAttribute('data-active', 'true')

    await expect(report.getByRole('heading')).toHaveText('Shopping 11 Funnel')

    await expect(report.getByText('3-step funnel')).toBeVisible()

    await expect(report.getByText('33.33% conversion rate')).toBeVisible()
  })

  await test.step('loading more', async () => {
    await funnelsTabButton.click()
    await dropdown(report).getByRole('button', { name: 'Show 1 more' }).click()
    await dropdown(report)
      .getByRole('button', { name: 'Shopping 1 Funnel' })
      .click()

    await expect(report.getByRole('heading')).toHaveText('Shopping 1 Funnel')
  })

  await test.step('searching', async () => {
    await funnelsTabButton.click()
    await searchInput(report).fill('Shopping 1')

    await expect(dropdown(report).getByRole('button')).toHaveText([
      'Shopping 11 Funnel',
      'Shopping 10 Funnel',
      'Shopping 1 Funnel'
    ])
  })
})
