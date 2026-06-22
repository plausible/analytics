import { test, expect } from '@playwright/test'
import { setupSite, populateStats, addCustomGoal } from '../fixtures'
import {
  tabButton,
  expectHeaders,
  expectRows,
  rowLink,
  expectMetricValues,
  dropdown,
  modal,
  detailsLink,
  closeModalButton,
  header,
  searchInput
} from '../test-utils'

test('sources breakdown', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        name: 'pageview',
        referrer_source: 'DuckDuckGo',

        referrer: 'https://duckduckgo.com/a1',
        utm_medium: 'paid'
      },
      {
        name: 'pageview',
        referrer_source: 'DuckDuckGo',
        referrer: 'https://duckduckgo.com/a2',
        click_id_param: 'gclid'
      },
      { name: 'pageview', referrer_source: 'Facebook', utm_source: 'fb' },
      { name: 'pageview', referrer_source: 'theguardian.com' },
      { name: 'pageview', referrer_source: 'ablog.example.com' },
      {
        name: 'pageview',
        referrer_source: 'Google',
        utm_medium: 'SomeUTMMedium',
        utm_source: 'SomeUTMSource',
        utm_campaign: 'SomeUTMCampaign',
        utm_content: 'SomeUTMContent',
        utm_term: 'SomeUTMTerm'
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const report = page.getByTestId('report-sources')

  await test.step('sources tab', async () => {
    const sourcesTabButton = tabButton(report, 'Sources')
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(sourcesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Source', 'Visitors'])

    await expectRows(report, [
      'DuckDuckGo',
      'Facebook',
      'Google',
      'ablog.example.com',
      'theguardian.com'
    ])

    await expectMetricValues(report, 'DuckDuckGo', ['2', '33.3%'])
    await expectMetricValues(report, 'Facebook', ['1', '16.7%'])
    await expectMetricValues(report, 'Google', ['1', '16.7%'])
    await expectMetricValues(report, 'ablog.example.com', ['1', '16.7%'])
    await expectMetricValues(report, 'theguardian.com', ['1', '16.7%'])
  })

  await test.step('sources modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top sources' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Source',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), [
      'DuckDuckGo',
      'Facebook',
      'Google',
      'ablog.example.com',
      'theguardian.com'
    ])

    await expectMetricValues(modal(page), 'DuckDuckGo', ['2', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('clicking sources entry shows referrers', async () => {
    await rowLink(report, 'DuckDuckGo').click()
    await expect(page).toHaveURL(/f=is,source,DuckDuckGo/)

    await expect(tabButton(report, 'Top referrers')).toHaveAttribute(
      'data-active',
      'true'
    )

    // Move mouse away from report rows
    await tabButton(report, 'Top referrers').hover()

    await expectHeaders(report, ['Referrer', 'Visitors'])

    await expectRows(report, [
      'https://duckduckgo.com/a1',
      'https://duckduckgo.com/a2'
    ])
  })

  await test.step('referrers modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Referrer drilldown' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Referrer',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), [
      'https://duckduckgo.com/a1',
      'https://duckduckgo.com/a2'
    ])

    await closeModalButton(page).click()

    await page
      .getByRole('button', { name: 'Remove filter: Source is DuckDuckGo' })
      .click()
  })

  // Tests against values from Plausible.Google.API.Mock
  await test.step('clicking Google source entry opens search terms', async () => {
    await rowLink(report, 'Google').click()
    await expect(page).toHaveURL(/f=is,source,Google/)

    await expect(tabButton(report, 'Search terms')).toHaveAttribute(
      'data-active',
      'true'
    )

    // Move mouse away from report rows
    await tabButton(report, 'Search terms').hover()

    await expectHeaders(report, ['Search term', 'Visitors'])

    await expectMetricValues(report, 'simple web analytics', ['25'])
    await expectMetricValues(report, 'open-source analytics', ['15'])
  })

  await test.step('search-terms modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Google search terms' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Search term',
      'Visitors',
      'Impressions',
      'CTR',
      'Position'
    ])

    await closeModalButton(page).click()
  })

  await page
    .getByRole('button', { name: 'Remove filter: Source is Google' })
    .click()

  await test.step('channels tab', async () => {
    const channelsTabButton = tabButton(report, 'Channels')
    await channelsTabButton.click()
    await expect(channelsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Channel', 'Visitors'])

    await expectRows(report, [
      'Organic Search',
      'Referral',
      'Organic Social',
      'Paid Search'
    ])

    await expectMetricValues(report, 'Organic Search', ['2', '33.3%'])
    await expectMetricValues(report, 'Referral', ['2', '33.3%'])
    await expectMetricValues(report, 'Organic Social', ['1', '16.7%'])
    await expectMetricValues(report, 'Paid Search', ['1', '16.7%'])
  })

  await test.step('channels modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top acquisition channels' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Channel',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), [
      'Organic Search',
      'Referral',
      'Organic Social',
      'Paid Search'
    ])

    await expectMetricValues(modal(page), 'Referral', ['2', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('campaigns > UTM mediums tab', async () => {
    await tabButton(report, 'Campaigns').click()
    await dropdown(report).getByRole('button', { name: 'UTM mediums' }).click()

    await expect(tabButton(report, 'UTM mediums')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['UTM medium', 'Visitors'])

    await expectRows(report, ['SomeUTMMedium', 'paid'])

    await expectMetricValues(report, 'SomeUTMMedium', ['1', '50%'])
    await expectMetricValues(report, 'paid', ['1', '50%'])
  })

  await test.step('UTM mediums modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'UTM mediums' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'UTM medium',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['SomeUTMMedium', 'paid'])

    await expectMetricValues(modal(page), 'SomeUTMMedium', ['1', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('campaigns > UTM sources tab', async () => {
    await tabButton(report, 'UTM mediums').click()
    await dropdown(report).getByRole('button', { name: 'UTM sources' }).click()

    await expect(tabButton(report, 'UTM sources')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['UTM source', 'Visitors'])

    await expectRows(report, ['SomeUTMSource', 'fb'])

    await expectMetricValues(report, 'SomeUTMSource', ['1', '50%'])
    await expectMetricValues(report, 'fb', ['1', '50%'])
  })

  await test.step('UTM sources modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'UTM sources' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'UTM source',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['SomeUTMSource', 'fb'])

    await expectMetricValues(modal(page), 'SomeUTMSource', ['1', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('campaigns > UTM campaigns tab', async () => {
    await tabButton(report, 'UTM sources').click()
    await dropdown(report)
      .getByRole('button', { name: 'UTM campaigns' })
      .click()

    await expect(tabButton(report, 'UTM campaigns')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['UTM campaign', 'Visitors'])

    await expectRows(report, ['SomeUTMCampaign'])

    await expectMetricValues(report, 'SomeUTMCampaign', ['1', '100%'])
  })

  await test.step('UTM campaigns modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'UTM campaigns' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'UTM campaign',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['SomeUTMCampaign'])

    await expectMetricValues(modal(page), 'SomeUTMCampaign', [
      '1',
      '100%',
      '0s'
    ])

    await closeModalButton(page).click()
  })

  await test.step('campaigns > UTM contents tab', async () => {
    await tabButton(report, 'UTM campaigns').click()
    await dropdown(report).getByRole('button', { name: 'UTM contents' }).click()

    await expect(tabButton(report, 'UTM contents')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['UTM content', 'Visitors'])

    await expectRows(report, ['SomeUTMContent'])

    await expectMetricValues(report, 'SomeUTMContent', ['1', '100%'])
  })

  await test.step('UTM contents modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'UTM contents' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'UTM content',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['SomeUTMContent'])

    await expectMetricValues(modal(page), 'SomeUTMContent', ['1', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('campaigns > UTM terms tab', async () => {
    await tabButton(report, 'UTM contents').click()
    await dropdown(report).getByRole('button', { name: 'UTM terms' }).click()

    await expect(tabButton(report, 'UTM terms')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['UTM term', 'Visitors'])

    await expectRows(report, ['SomeUTMTerm'])

    await expectMetricValues(report, 'SomeUTMTerm', ['1', '100%'])
  })

  await test.step('UTM terms modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'UTM terms' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'UTM term',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['SomeUTMTerm'])

    await expectMetricValues(modal(page), 'SomeUTMTerm', ['1', '100%', '0s'])

    await closeModalButton(page).click()
  })
})

// Tests against values from Plausible.Google.API.Mock
test('sources breakdown - search terms failure modes', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', referrer_source: 'Google', pathname: '/empty' },
      {
        name: 'pageview',
        referrer_source: 'Google',
        pathname: '/unsupported-filters'
      },
      {
        name: 'pageview',
        referrer_source: 'Google',
        pathname: '/not-configured'
      }
    ]
  })

  const report = page.getByTestId('report-sources')
  const searchTermsTabButton = tabButton(report, 'Search terms')

  await test.step('empty', async () => {
    await page.goto('/' + domain + '?f=is,source,Google&f=is,page,%2Fempty', {
      waitUntil: 'commit'
    })

    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(searchTermsTabButton).toHaveAttribute('data-active', 'true')

    await expect(report.getByText('No data yet')).toBeVisible()
  })

  await test.step('unsupported filters', async () => {
    await page.goto(
      '/' + domain + '?f=is,source,Google&f=is,page,%2Funsupported-filters',
      {
        waitUntil: 'commit'
      }
    )

    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(searchTermsTabButton).toHaveAttribute('data-active', 'true')

    await expect(
      report.getByText('Unable to fetch keyword data from Search Console')
    ).toBeVisible()

    await expect(
      report.getByText('does not support the current set of filters')
    ).toBeVisible()
  })

  await test.step('not configured', async () => {
    await page.goto(
      '/' + domain + '?f=is,source,Google&f=is,page,%2Fnot-configured',
      {
        waitUntil: 'commit'
      }
    )

    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(searchTermsTabButton).toHaveAttribute('data-active', 'true')

    await expect(
      report.getByText('The site is not connected to Google Search Keywords')
    ).toBeVisible()
  })
})

test('pages breakdown', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      { user_id: 123, name: 'pageview', pathname: '/page1' },
      { user_id: 123, name: 'pageview', pathname: '/page2' },
      { user_id: 123, name: 'pageview', pathname: '/page3' },
      { user_id: 124, name: 'pageview', pathname: '/page1' },
      { user_id: 124, name: 'pageview', pathname: '/page2' },
      { name: 'pageview', pathname: '/page1' },
      { name: 'pageview', pathname: '/other' }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const report = page.getByTestId('report-pages')

  await test.step('top pages tab', async () => {
    const pagesTabButton = tabButton(report, 'Top pages')
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(pagesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Page', 'Visitors'])

    await expectRows(report, ['/page1', '/page2', '/other', '/page3'])

    await expectMetricValues(report, '/page1', ['3', '75%'])
    await expectMetricValues(report, '/page2', ['2', '50%'])
    await expectMetricValues(report, '/other', ['1', '25%'])
    await expectMetricValues(report, '/page3', ['1', '25%'])
  })

  await test.step('entry pages tab', async () => {
    const entryPagesTabButton = tabButton(report, 'Entry pages')
    entryPagesTabButton.click()
    await expect(entryPagesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Entry page', 'Unique entrances'])

    await expectRows(report, ['/page1', '/other'])

    await expectMetricValues(report, '/page1', ['3', '75%'])
    await expectMetricValues(report, '/other', ['1', '25%'])
  })

  await test.step('Entry pages modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Entry pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Entry page',
      /Unique entrances/,
      /Total entrances/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['/page1', '/other'])

    await expectMetricValues(modal(page), '/page1', ['3', '3', '33%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('exit pages tab', async () => {
    const exitPagesTabButton = tabButton(report, 'Exit pages')
    exitPagesTabButton.click()
    await expect(exitPagesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Exit page', 'Unique exits'])

    await expectRows(report, ['/other', '/page1', '/page2', '/page3'])

    await expectMetricValues(report, '/other', ['1', '25%'])
    await expectMetricValues(report, '/page1', ['1', '25%'])
    await expectMetricValues(report, '/page2', ['1', '25%'])
    await expectMetricValues(report, '/page3', ['1', '25%'])
  })

  await test.step('Exit pages modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Exit pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Exit page',
      /Unique exits/,
      /Total exits/,
      /Exit rate/
    ])

    await expectRows(modal(page), ['/other', '/page1', '/page2', '/page3'])

    await expectMetricValues(modal(page), '/other', ['1', '1', '100%'])

    await closeModalButton(page).click()
  })

  await test.step('exit pages modal with an event filter applied', async () => {
    await page.goto('/' + domain + '?f=is,page,/page1', { waitUntil: 'commit' })
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Exit pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Exit page',
      /Unique exits/,
      /Total exits/
    ])

    await expectRows(modal(page), ['/page1', '/page2', '/page3'])

    await expectMetricValues(modal(page), '/page1', ['1', '1'])
    await expectMetricValues(modal(page), '/page2', ['1', '1'])
    await expectMetricValues(modal(page), '/page3', ['1', '1'])

    await closeModalButton(page).click()
  })
})

test('pages breakdown modal', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  const pagesCount = 110

  // We generate <pagesCount> unique page entries, each with a different number of visits
  const pageEvents = Array(pagesCount)
    .fill(null)
    .map((_, idx) => {
      return Array(idx + 1)
        .fill(null)
        .map(() => {
          return { name: 'pageview', pathname: `/page${idx + 1}/foo` }
        })
    })
    .flat()

  await populateStats({
    request,
    domain,
    events: pageEvents
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const report = page.getByTestId('report-pages')

  const pagesTabButton = tabButton(report, 'Top pages')
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()
  await expect(pagesTabButton).toHaveAttribute('data-active', 'true')

  await detailsLink(report).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Top pages' })
  ).toBeVisible()

  await expectHeaders(modal(page), [
    'Page',
    /Visitors/,
    /Pageviews/,
    /Bounce rate/,
    /Time on page/,
    /Scroll depth/
  ])

  await test.step('displays 100 entries on a single page', async () => {
    const pageRows = Array(100)
      .fill(null)
      .map((_, idx) => {
        return `/page${pagesCount - idx}/foo`
      })

    await expectRows(modal(page), pageRows)

    await expectMetricValues(modal(page), '/page110/foo', [
      '110',
      '110',
      '100%',
      '-',
      '-'
    ])

    await expectMetricValues(modal(page), '/page11/foo', [
      '11',
      '11',
      '100%',
      '-',
      '-'
    ])
  })

  await test.step('loads more when requested', async () => {
    const loadMoreButton = modal(page).getByRole('button', {
      name: 'Load more'
    })

    await loadMoreButton.scrollIntoViewIfNeeded()
    await loadMoreButton.click()

    await expectMetricValues(modal(page), '/page10/foo', [
      '10',
      '10',
      '100%',
      '-',
      '-'
    ])

    await expectMetricValues(modal(page), '/page1/foo', [
      '1',
      '1',
      '100%',
      '-',
      '-'
    ])
  })

  await test.step('sorts when clicking on column header', async () => {
    await header(modal(page), 'Visitors').click()

    const pageRows = Array(100)
      .fill(null)
      .map((_, idx) => {
        return `/page${idx + 1}/foo`
      })

    await expectRows(modal(page), pageRows)
  })

  await test.step('filters when using search', async () => {
    await searchInput(modal(page)).fill('page9')

    await expectRows(modal(page), [
      '/page9/foo',
      '/page90/foo',
      '/page91/foo',
      '/page92/foo',
      '/page93/foo',
      '/page94/foo',
      '/page95/foo',
      '/page96/foo',
      '/page97/foo',
      '/page98/foo',
      '/page99/foo'
    ])
  })

  await test.step('close button closes the modal', async () => {
    await closeModalButton(page).click()

    await expect(modal(page)).toBeHidden()
  })

  await test.step('reopening the modal resets the search state but preserves', async () => {
    await detailsLink(report).click()

    await expect(modal(page)).toContainClass('is-open')

    await expect(searchInput(modal(page))).toHaveValue('')

    const pageRows = Array(100)
      .fill(null)
      .map((_, idx) => {
        return `/page${idx + 1}/foo`
      })

    await expectRows(modal(page), pageRows)
  })
})

test('pages breakdown with a pageview goal filter applied', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      { user_id: 123, name: 'pageview', pathname: '/page1' },
      { user_id: 123, name: 'pageview', pathname: '/page2' },
      { user_id: 123, name: 'pageview', pathname: '/page3' },
      {
        user_id: 123,
        name: 'purchase',
        revenue_reporting_amount: '23',
        revenue_reporting_currency: 'EUR'
      },
      { user_id: 124, name: 'pageview', pathname: '/page1' },
      { user_id: 124, name: 'pageview', pathname: '/page2' },
      { user_id: 124, name: 'create_site' },
      { name: 'pageview', pathname: '/page1' },
      { name: 'pageview', pathname: '/other' }
    ]
  })

  await addCustomGoal({ page, domain, name: 'create_site' })
  await addCustomGoal({ page, domain, name: 'purchase', currency: 'EUR' })

  const report = page.getByTestId('report-pages')

  await test.step('custom goal filter applied', async () => {
    await page.goto('/' + domain + '?f=is,goal,create_site', {
      waitUntil: 'commit'
    })

    const pagesTabButton = tabButton(report, 'Conversion pages')
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(pagesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Page', 'Conversions', 'CR'])

    await expectRows(report, ['/'])

    await expectMetricValues(report, '/', ['1', '50%'])
  })

  await test.step('details modal after custom goal filter applied', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Page',
      /Total visitors/,
      /Conversions/,
      /CR/
    ])

    await expectRows(modal(page), ['/'])

    await expectMetricValues(modal(page), '/', ['2', '1', '50%'])

    await closeModalButton(page).click()
  })

  await test.step('revenue goal filter applied', async () => {
    await page.goto('/' + domain + '?f=is,goal,purchase', {
      waitUntil: 'commit'
    })

    const pagesTabButton = tabButton(report, 'Conversion pages')
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(pagesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Page', 'Conversions', 'CR'])

    await expectRows(report, ['/'])

    await expectMetricValues(report, '/', ['1', '50%'])
  })

  await test.step('details modal after revenue goal filter applied', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Page',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), ['/'])

    await expectMetricValues(modal(page), '/', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])

    await closeModalButton(page).click()
  })
})

test('pages breakdown - URL mode', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 1,
        name: 'pageview',
        hostname: 'blog.example.com',
        pathname: '/post'
      },
      {
        user_id: 1,
        name: 'pageview',
        hostname: 'blog.example.com',
        pathname: '/post'
      },
      {
        user_id: 2,
        name: 'pageview',
        hostname: 'blog.example.com',
        pathname: '/post'
      },
      {
        user_id: 3,
        name: 'pageview',
        hostname: 'docs.example.com',
        pathname: '/api'
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })
  const report = page.getByTestId('report-pages')

  await test.step('switch to URL mode', async () => {
    await report.getByRole('button', { name: 'Breakdown options' }).click()
    await page.getByRole('button', { name: 'URL' }).click()
  })

  await test.step('top pages in URL mode', async () => {
    await expect(tabButton(report, 'Top pages')).toHaveAttribute(
      'data-active',
      'true'
    )

    await expectHeaders(report, ['URL', 'Visitors'])
    await expectRows(report, ['blog.example.com/post', 'docs.example.com/api'])
    await expectMetricValues(report, 'blog.example.com/post', ['2', '66.7%'])
    await expectMetricValues(report, 'docs.example.com/api', ['1', '33.3%'])
  })

  await test.step('clicking a URL mode row applies hostname and page filters', async () => {
    await rowLink(report, 'blog.example.com/post').click()

    await expect(
      page.getByRole('button', {
        name: 'Remove filter: Hostname is blog.example.com'
      })
    ).toBeVisible()
    await expect(
      page.getByRole('button', { name: 'Remove filter: Page is /post' })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Hostname is blog.example.com'
      })
      .click()
    await page
      .getByRole('button', { name: 'Remove filter: Page is /post' })
      .click()
  })

  await test.step('entry pages in URL mode', async () => {
    await tabButton(report, 'Entry pages').click()

    await expectHeaders(report, ['URL', 'Unique entrances'])
    await expectRows(report, ['blog.example.com/post', 'docs.example.com/api'])
    await expectMetricValues(report, 'blog.example.com/post', ['2', '66.7%'])
    await expectMetricValues(report, 'docs.example.com/api', ['1', '33.3%'])
  })

  await test.step('entry pages modal in URL mode', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Entry pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'URL',
      /Unique entrances/,
      /Total entrances/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), [
      'blog.example.com/post',
      'docs.example.com/api'
    ])

    await closeModalButton(page).click()
  })

  await test.step('exit pages in URL mode', async () => {
    await tabButton(report, 'Exit pages').click()

    await expectHeaders(report, ['URL', 'Unique exits'])
    await expectRows(report, ['blog.example.com/post', 'docs.example.com/api'])
  })

  await test.step('exit pages modal in URL mode', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Exit pages' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'URL',
      /Unique exits/,
      /Total exits/,
      /Exit rate/
    ])

    await expectRows(modal(page), [
      'blog.example.com/post',
      'docs.example.com/api'
    ])

    await closeModalButton(page).click()
  })
})

test('locations breakdown', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        name: 'pageview',
        country_code: 'EE',
        subdivision1_code: 'EE-37',
        city_geoname_id: 588_409
      },
      {
        name: 'pageview',
        country_code: 'EE',
        subdivision1_code: 'EE-79',
        city_geoname_id: 588_335
      },
      {
        name: 'pageview',
        country_code: 'PL',
        subdivision1_code: 'PL-14',
        city_geoname_id: 756_135
      },
      {
        name: 'pageview',
        country_code: ''
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const report = page.getByTestId('report-locations')

  await test.step('map tab', async () => {
    const mapTabButton = tabButton(report, 'Map')
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(mapTabButton).toHaveAttribute('data-active', 'true')

    // NOTE: We only check that the map is there
    await expect(report.locator('svg path.country').first()).toBeVisible()
  })

  await test.step('countries tab', async () => {
    const countriesTabButton = tabButton(report, 'Countries')
    await countriesTabButton.click()
    await expect(countriesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Country', 'Visitors'])

    await expectRows(report, [/Estonia/, /Poland/])

    await expectMetricValues(report, 'Estonia', ['2', '66.7%'])
    await expectMetricValues(report, 'Poland', ['1', '33.3%'])
  })

  await test.step('countries modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top countries' })
    ).toBeVisible()

    await expectHeaders(modal(page), ['Country', /Visitors/])

    await expectRows(modal(page), [/Estonia/, /Poland/])

    await expectMetricValues(modal(page), 'Estonia', ['2'])

    await expect(searchInput(modal(page))).toBeVisible()

    await searchInput(modal(page)).fill('Esto')
    await expectRows(modal(page), [/Estonia/])

    await searchInput(modal(page)).fill('')
    await expectRows(modal(page), [/Estonia/, /Poland/])

    await closeModalButton(page).click()
  })

  const regionsTabButton = tabButton(report, 'Regions')

  await test.step('clicking country entry shows regions', async () => {
    await rowLink(report, 'Estonia').click()
    await expect(page).toHaveURL(/f=is,country,EE/)

    await expect(regionsTabButton).toHaveAttribute('data-active', 'true')

    await page
      .getByRole('button', { name: 'Remove filter: Country is Estonia' })
      .click()
  })

  await test.step('regions tab', async () => {
    await regionsTabButton.click()
    await expect(regionsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Region', 'Visitors'])

    await expectRows(report, [/Harjumaa/, /Mazovia/, /Tartumaa/])

    await expectMetricValues(report, 'Harjumaa', ['1', '33.3%'])
    await expectMetricValues(report, 'Tartumaa', ['1', '33.3%'])
    await expectMetricValues(report, 'Mazovia', ['1', '33.3%'])
  })

  await test.step('regions modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top regions' })
    ).toBeVisible()

    await expectHeaders(modal(page), ['Region', /Visitors/])

    await expectRows(modal(page), [/Harjumaa/, /Mazovia/, /Tartumaa/])

    await expectMetricValues(modal(page), 'Harjumaa', ['1'])

    await expect(searchInput(modal(page))).toBeVisible()

    await searchInput(modal(page)).fill('Harju')
    await expectRows(modal(page), [/Harjumaa/])

    await searchInput(modal(page)).fill('')
    await expectRows(modal(page), [/Harjumaa/, /Mazovia/, /Tartumaa/])

    await closeModalButton(page).click()
  })

  const citiesTabButton = tabButton(report, 'Cities')

  await test.step('clicking region entry shows cities', async () => {
    await rowLink(report, 'Harjumaa').click()
    await expect(page).toHaveURL(/f=is,region,EE-37/)

    await expect(citiesTabButton).toHaveAttribute('data-active', 'true')

    await page
      .getByRole('button', { name: 'Remove filter: Region is Harjumaa' })
      .click()
  })

  await test.step('cities tab', async () => {
    await citiesTabButton.click()
    await expect(citiesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['City', 'Visitors'])

    await expectRows(report, [/Tallinn/, /Tartu/, /Warsaw/])

    await expectMetricValues(report, 'Tartu', ['1', '33.3%'])
    await expectMetricValues(report, 'Tallinn', ['1', '33.3%'])
    await expectMetricValues(report, 'Warsaw', ['1', '33.3%'])
  })

  await test.step('cities modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top cities' })
    ).toBeVisible()

    await expectHeaders(modal(page), ['City', /Visitors/])

    await expectRows(modal(page), [/Tallinn/, /Tartu/, /Warsaw/])

    await expectMetricValues(modal(page), 'Tartu', ['1'])

    await expect(searchInput(modal(page))).toBeVisible()

    await searchInput(modal(page)).fill('Tallinn')
    await expectRows(modal(page), [/Tallinn/])

    await searchInput(modal(page)).fill('')
    await expectRows(modal(page), [/Tallinn/, /Tartu/, /Warsaw/])

    await closeModalButton(page).click()
  })
})

test('locations breakdown with a revenue goal filter applied', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 1,
        name: 'pageview',
        country_code: 'A1'
      },
      {
        user_id: 2,
        name: 'pageview',
        country_code: 'A1'
      },
      {
        user_id: 2,
        name: 'purchase',
        revenue_reporting_amount: '23',
        revenue_reporting_currency: 'EUR',
        country_code: 'A1'
      },
      {
        user_id: 3,
        name: 'pageview',
        country_code: 'PL',
        subdivision1_code: 'PL-14',
        city_geoname_id: 756_135
      },
      {
        user_id: 4,
        name: 'pageview',
        country_code: 'EE',
        subdivision1_code: 'EE-37',
        city_geoname_id: 588_409
      },
      {
        user_id: 4,
        name: 'purchase',
        revenue_reporting_amount: '12345.67',
        revenue_reporting_currency: 'EUR',
        country_code: 'EE',
        subdivision1_code: 'EE-37',
        city_geoname_id: 588_409
      }
    ]
  })

  await addCustomGoal({ page, domain, name: 'purchase', currency: 'EUR' })

  await page.goto('/' + domain + '?f=is,goal,purchase', {
    waitUntil: 'commit'
  })

  const report = page.getByTestId('report-locations')

  await test.step('countries report shows conversions for revenue goal', async () => {
    await tabButton(report, 'Countries').click()
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()

    await expectHeaders(report, ['Country', 'Conversions', 'CR'])

    await expectRows(report, [/Anonymous VPN Service/, /Estonia/])

    await expectMetricValues(report, 'Anonymous VPN Service', ['1', '50%'])
    await expectMetricValues(report, 'Estonia', ['1', '100%'])
  })

  await test.step('countries details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top countries' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Country',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), [/Anonymous VPN Service/, /Estonia/])

    await expectMetricValues(modal(page), 'Anonymous VPN Service', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])
    await expectMetricValues(modal(page), 'Estonia', [
      '1',
      '1',
      '100%',
      '€12.3K',
      '€12.3K'
    ])

    await closeModalButton(page).click()
  })

  await test.step('regions report shows conversions for revenue goal', async () => {
    await tabButton(report, 'Regions').click()

    await expectHeaders(report, ['Region', 'Conversions', 'CR'])

    await expectRows(report, [/Harjumaa/])

    await expectMetricValues(report, 'Harjumaa', ['1', '100%'])
  })

  await test.step('regions details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top regions' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Region',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), [/Harjumaa/])

    await expectMetricValues(modal(page), 'Harjumaa', [
      '1',
      '1',
      '100%',
      '€12.3K',
      '€12.3K'
    ])

    await closeModalButton(page).click()
  })

  await test.step('cities report shows conversions for revenue goal', async () => {
    await tabButton(report, 'Cities').click()

    await expectHeaders(report, ['City', 'Conversions', 'CR'])

    await expectRows(report, [/Tallinn/])

    await expectMetricValues(report, 'Tallinn', ['1', '100%'])
  })

  await test.step('cities details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top cities' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'City',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), [/Tallinn/])

    await expectMetricValues(modal(page), 'Tallinn', [
      '1',
      '1',
      '100%',
      '€12.3K',
      '€12.3K'
    ])

    await closeModalButton(page).click()
  })
})

test('devices breakdown', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        name: 'pageview',
        screen_size: 'Desktop',
        browser: 'Chrome',
        browser_version: '14.0.7',
        operating_system: 'Windows',
        operating_system_version: '11'
      },
      {
        name: 'pageview',
        screen_size: 'Desktop',
        browser: 'Firefox',
        browser_version: '98',
        operating_system: 'MacOS',
        operating_system_version: '10.15'
      },
      {
        name: 'pageview',
        screen_size: 'Mobile',
        browser: 'Safari',
        browser_version: '123',
        operating_system: 'iOS',
        operating_system_version: '16.15'
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  const report = page.getByTestId('report-devices')

  const browsersTabButton = tabButton(report, 'Browsers')

  await test.step('browsers tab', async () => {
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()
    await expect(browsersTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Browser', 'Visitors'])

    await expectRows(report, ['Chrome', 'Firefox', 'Safari'])

    await expectMetricValues(report, 'Chrome', ['1', '33.3%'])
    await expectMetricValues(report, 'Firefox', ['1', '33.3%'])
    await expectMetricValues(report, 'Safari', ['1', '33.3%'])
  })

  await test.step('browsers modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Browsers' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Browser',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['Chrome', 'Firefox', 'Safari'])

    await expectMetricValues(modal(page), 'Chrome', ['1', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('browser versions', async () => {
    await rowLink(report, 'Firefox').click()

    await expect(page).toHaveURL(/f=is,browser,Firefox/)

    await expect(browsersTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Browser version', 'Visitors'])

    await expectRows(report, ['Firefox 98'])

    await expectMetricValues(report, 'Firefox 98', ['1', '100%'])
  })

  await test.step('browser versions modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Browser versions' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Browser version',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['98'])

    await expectMetricValues(modal(page), '98', ['1', '100%', '0s'])

    await closeModalButton(page).click()

    await page
      .getByRole('button', { name: 'Remove filter: Browser is Firefox' })
      .click()
  })

  const osTabButton = tabButton(report, 'Operating systems')

  await test.step('operating systems tab', async () => {
    await osTabButton.click()
    await expect(osTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Operating system', 'Visitors'])

    await expectRows(report, ['MacOS', 'Windows', 'iOS'])

    await expectMetricValues(report, 'MacOS', ['1', '33.3%'])
    await expectMetricValues(report, 'Windows', ['1', '33.3%'])
    await expectMetricValues(report, 'iOS', ['1', '33.3%'])
  })

  await test.step('operating systems modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Operating systems' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Operating system',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['MacOS', 'Windows', 'iOS'])

    await expectMetricValues(modal(page), 'MacOS', ['1', '100%', '0s'])

    await closeModalButton(page).click()
  })

  await test.step('operating system versions', async () => {
    await rowLink(report, 'Windows').click()

    await expect(page).toHaveURL(/f=is,os,Windows/)

    await expect(osTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Operating system version', 'Visitors'])

    await expectRows(report, ['Windows 11'])

    await expectMetricValues(report, 'Windows 11', ['1', '100%'])
  })

  await test.step('operating system versions modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Operating system versions' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Operating system version',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['11'])

    await expectMetricValues(modal(page), '11', ['1', '100%', '0s'])

    await closeModalButton(page).click()

    await page
      .getByRole('button', {
        name: 'Remove filter: Operating system is Windows'
      })
      .click()
  })

  await test.step('devices tab', async () => {
    const devicesTabButton = tabButton(report, 'Devices')
    await devicesTabButton.click()
    await expect(devicesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Device', 'Visitors'])

    await expectRows(report, ['Desktop', 'Mobile'])

    await expectMetricValues(report, 'Desktop', ['2', '66.7%'])
    await expectMetricValues(report, 'Mobile', ['1', '33.3%'])
  })

  await test.step('devices modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Devices' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Device',
      /Visitors/,
      /Bounce rate/,
      /Visit duration/
    ])

    await expectRows(modal(page), ['Desktop', 'Mobile'])

    await expectMetricValues(modal(page), 'Desktop', ['2', '100%', '0s'])

    await closeModalButton(page).click()
  })
})

test('devices breakdown with a revenue goal filter applied', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 1,
        name: 'pageview',
        screen_size: 'Desktop',
        browser: 'Chrome',
        browser_version: '14.0.7',
        operating_system: 'Windows',
        operating_system_version: '11'
      },
      {
        user_id: 1,
        name: 'purchase',
        revenue_reporting_amount: '23',
        revenue_reporting_currency: 'EUR'
      },
      {
        user_id: 2,
        name: 'pageview',
        screen_size: 'Desktop',
        browser: 'Chrome',
        browser_version: '14.0.7',
        operating_system: 'Windows',
        operating_system_version: '11'
      },
      {
        user_id: 3,
        name: 'pageview',
        screen_size: 'Mobile',
        browser: 'Firefox',
        browser_version: '98',
        operating_system: 'MacOS',
        operating_system_version: '10.15'
      },
      {
        user_id: 3,
        name: 'purchase',
        revenue_reporting_amount: '12345.67',
        revenue_reporting_currency: 'EUR'
      }
    ]
  })

  await addCustomGoal({ page, domain, name: 'purchase', currency: 'EUR' })

  await page.goto('/' + domain + '?f=is,goal,purchase', {
    waitUntil: 'commit'
  })

  const report = page.getByTestId('report-devices')

  await test.step('browsers report shows conversions for revenue goal', async () => {
    await tabButton(report, 'Browsers').click()
    await report.getByTestId('report-end').scrollIntoViewIfNeeded()

    await expectHeaders(report, ['Browser', 'Conversions', 'CR'])

    await expectRows(report, ['Chrome', 'Firefox'])

    await expectMetricValues(report, 'Chrome', ['1', '50%'])
    await expectMetricValues(report, 'Firefox', ['1', '100%'])
  })

  await test.step('browsers details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Browsers' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Browser',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), ['Chrome', 'Firefox'])

    await expectMetricValues(modal(page), 'Chrome', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])
    await expectMetricValues(modal(page), 'Firefox', [
      '1',
      '1',
      '100%',
      '€12.3K',
      '€12.3K'
    ])

    await closeModalButton(page).click()
  })

  await test.step('browser versions report shows conversions for revenue goal', async () => {
    await rowLink(report, 'Chrome').click()

    await expect(page).toHaveURL(/f=is,browser,Chrome/)

    await expectHeaders(report, ['Browser version', 'Conversions', 'CR'])

    await expectRows(report, ['Chrome 14.0.7'])

    await expectMetricValues(report, 'Chrome 14.0.7', ['1', '50%'])
  })

  await test.step('browser versions details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Browser versions' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Browser version',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), ['14.0.7'])

    await expectMetricValues(modal(page), '14.0.7', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])

    await closeModalButton(page).click()

    await page
      .getByRole('button', { name: 'Remove filter: Browser is Chrome' })
      .click()
  })

  await test.step('operating systems report shows conversions for revenue goal', async () => {
    await tabButton(report, 'Operating systems').click()

    await expectHeaders(report, ['Operating system', 'Conversions', 'CR'])

    await expectRows(report, ['MacOS', 'Windows'])

    await expectMetricValues(report, 'MacOS', ['1', '100%'])
    await expectMetricValues(report, 'Windows', ['1', '50%'])
  })

  await test.step('operating systems details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Operating systems' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Operating system',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), ['MacOS', 'Windows'])

    await expectMetricValues(modal(page), 'MacOS', [
      '1',
      '1',
      '100%',
      '€12.3K',
      '€12.3K'
    ])
    await expectMetricValues(modal(page), 'Windows', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])

    await closeModalButton(page).click()
  })

  await test.step('operating system versions report shows conversions for revenue goal', async () => {
    await rowLink(report, 'Windows').click()

    await expect(page).toHaveURL(/f=is,os,Windows/)

    await expectHeaders(report, [
      'Operating system version',
      'Conversions',
      'CR'
    ])

    await expectRows(report, ['Windows 11'])

    await expectMetricValues(report, 'Windows 11', ['1', '50%'])
  })

  await test.step('operating system versions details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Operating system versions' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Operating system version',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), ['11'])

    await expectMetricValues(modal(page), '11', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])

    await closeModalButton(page).click()

    await page
      .getByRole('button', {
        name: 'Remove filter: Operating system is Windows'
      })
      .click()
  })

  await test.step('devices report shows conversions for revenue goal', async () => {
    await tabButton(report, 'Devices').click()

    await expectHeaders(report, ['Device', 'Conversions', 'CR'])

    await expectRows(report, ['Desktop', 'Mobile'])

    await expectMetricValues(report, 'Desktop', ['1', '50%'])
    await expectMetricValues(report, 'Mobile', ['1', '100%'])
  })

  await test.step('devices details modal includes revenue columns', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Devices' })
    ).toBeVisible()

    await expectHeaders(modal(page), [
      'Device',
      /Total visitors/,
      /Conversions/,
      /CR/,
      /Revenue/,
      /Average/
    ])

    await expectRows(modal(page), ['Desktop', 'Mobile'])

    await expectMetricValues(modal(page), 'Desktop', [
      '2',
      '1',
      '50%',
      '€23.0',
      '€23.0'
    ])
    await expectMetricValues(modal(page), 'Mobile', [
      '1',
      '1',
      '100%',
      '€12.3K',
      '€12.3K'
    ])

    await closeModalButton(page).click()
  })
})
