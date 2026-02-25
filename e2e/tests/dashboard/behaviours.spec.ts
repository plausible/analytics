import { test, expect } from '@playwright/test'
import {
  setupSite,
  populateStats,
  addCustomGoal,
  addPageviewGoal,
  addScrollDepthGoal,
  addAllCustomProps,
  addFunnel
} from '../fixtures.ts'
import {
  tabButton,
  expectHeaders,
  expectRows,
  rowLink,
  expectMetricValues,
  dropdown
} from '../test-utils.ts'

const getReport = (page) => page.getByTestId('report-behaviours')

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

  await page.goto('/' + domain)

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

  await test.step('listing goals without revenue', async () => {
    await page.goto('/' + domain + '?f=has_not_done,goal,purchase')

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
        'meta.key': ['logged_in', 'browser_language'],
        'meta.value': ['false', 'en_US']
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

  await page.goto('/' + domain)

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

  await test.step('clicking goal opens props', async () => {
    const goalsTabButton = tabButton(report, 'Goals')
    goalsTabButton.click()

    await expect(goalsTabButton).toHaveAttribute('data-active', 'true')

    await rowLink(report, 'Visit /page').click()

    await expect(propsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['browser_language', 'Visitors', 'Events', 'CR'])

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
  await addFunnel({
    page,
    domain,
    name: 'Shopping',
    steps: ['Visit /products', 'Visit /cart', 'Visit /checkout']
  })

  await page.goto('/' + domain)

  const funnelsTabButton = tabButton(report, 'Funnels')

  await funnelsTabButton.scrollIntoViewIfNeeded()
  await funnelsTabButton.click()
  await dropdown(report).getByRole('button', { name: 'Shopping' }).click()

  await expect(funnelsTabButton).toHaveAttribute('data-active', 'true')

  await expect(report.getByRole('heading')).toHaveText('Shopping')

  await expect(report.getByText('3-step funnel')).toBeVisible()

  await expect(report.getByText('33.33% conversion rate')).toBeVisible()
})
