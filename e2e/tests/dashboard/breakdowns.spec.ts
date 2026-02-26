import { test, expect } from '@playwright/test'
import { setupSite, populateStats, addCustomGoal } from '../fixtures.ts'
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
  header
} from '../test-utils.ts'

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
        utm_medium: 'SomeUTMMedium',
        utm_source: 'SomeUTMSource',
        utm_campaign: 'SomeUTMCampaign',
        utm_content: 'SomeUTMContent',
        utm_term: 'SomeUTMTerm'
      }
    ]
  })

  await page.goto('/' + domain)

  const report = page.getByTestId('report-sources')

  await test.step('sources tab', async () => {
    const sourcesTabButton = tabButton(report, 'Sources')
    await sourcesTabButton.scrollIntoViewIfNeeded()
    await expect(sourcesTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Source', 'Visitors'])

    await expectRows(report, [
      'DuckDuckGo',
      'Direct / None',
      'Facebook',
      'ablog.example.com',
      'theguardian.com'
    ])

    await expectMetricValues(report, 'DuckDuckGo', ['2', '33.3%'])
    await expectMetricValues(report, 'Direct / None', ['1', '16.7%'])
    await expectMetricValues(report, 'Facebook', ['1', '16.7%'])
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
      'Direct / None',
      'Facebook',
      'ablog.example.com',
      'theguardian.com'
    ])

    await expectMetricValues(modal(page), 'DuckDuckGo', ['2', '100%', '0s'])

    await closeModalButton(page).click()
  })

  const referrersReport = page.getByTestId('report-referrers')

  await test.step('clicking sources entry shows referrers', async () => {
    await rowLink(report, 'DuckDuckGo').click()
    await expect(page).toHaveURL(/f=is,source,DuckDuckGo/)

    await expect(tabButton(referrersReport, 'Top referrers')).toHaveAttribute(
      'data-active',
      'true'
    )

    // Move mouse away from report rows
    await tabButton(referrersReport, 'Top referrers').hover()

    await expectHeaders(referrersReport, ['Referrer', 'Visitors'])

    await expectRows(referrersReport, [
      'https://duckduckgo.com/a1',
      'https://duckduckgo.com/a2'
    ])
  })

  await test.step('referrers modal', async () => {
    await detailsLink(referrersReport).click()

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

  await test.step('channels tab', async () => {
    const channelsTabButton = tabButton(report, 'Channels')
    await channelsTabButton.click()
    await expect(channelsTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Channel', 'Visitors'])

    await expectRows(report, [
      'Referral',
      'Direct',
      'Organic Search',
      'Organic Social',
      'Paid Search'
    ])

    await expectMetricValues(report, 'Referral', ['2', '33.3%'])
    await expectMetricValues(report, 'Direct', ['1', '16.7%'])
    await expectMetricValues(report, 'Organic Search', ['1', '16.7%'])
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
      'Referral',
      'Direct',
      'Organic Search',
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

    await expectHeaders(report, ['Medium', 'Visitors'])

    await expectRows(report, ['SomeUTMMedium', 'paid'])

    await expectMetricValues(report, 'SomeUTMMedium', ['1', '50%'])
    await expectMetricValues(report, 'paid', ['1', '50%'])
  })

  await test.step('UTM mediums modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top UTM mediums' })
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

    await expectHeaders(report, ['Source', 'Visitors'])

    await expectRows(report, ['SomeUTMSource', 'fb'])

    await expectMetricValues(report, 'SomeUTMSource', ['1', '50%'])
    await expectMetricValues(report, 'fb', ['1', '50%'])
  })

  await test.step('UTM sources modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top UTM sources' })
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

    await expectHeaders(report, ['Campaign', 'Visitors'])

    await expectRows(report, ['SomeUTMCampaign'])

    await expectMetricValues(report, 'SomeUTMCampaign', ['1', '100%'])
  })

  await test.step('UTM campaigns modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top UTM campaigns' })
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

    await expectHeaders(report, ['Content', 'Visitors'])

    await expectRows(report, ['SomeUTMContent'])

    await expectMetricValues(report, 'SomeUTMContent', ['1', '100%'])
  })

  await test.step('UTM contents modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top UTM contents' })
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

    await expectHeaders(report, ['Term', 'Visitors'])

    await expectRows(report, ['SomeUTMTerm'])

    await expectMetricValues(report, 'SomeUTMTerm', ['1', '100%'])
  })

  await test.step('UTM terms modal', async () => {
    await detailsLink(report).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Top UTM terms' })
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

  await page.goto('/' + domain)

  const report = page.getByTestId('report-pages')

  await test.step('top pages tab', async () => {
    const pagesTabButton = tabButton(report, 'Top pages')
    await pagesTabButton.scrollIntoViewIfNeeded()
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
      /Visitors/,
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
      'Page url',
      /Visitors/,
      /Total exits/,
      /Exit rate/
    ])

    await expectRows(modal(page), ['/other', '/page1', '/page2', '/page3'])

    await expectMetricValues(modal(page), '/other', ['1', '1', '100%'])

    await closeModalButton(page).click()
  })
})

test('pages breakdown modal', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  const pagesCount = 110

  // We generate <pagesCount> unique page entries, each with a different number of visits
  const pageEvents = Array(pagesCount)
    .fill()
    .map((_, idx) => {
      return Array(idx + 1)
        .fill()
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

  await page.goto('/' + domain)

  const report = page.getByTestId('report-pages')

  const pagesTabButton = tabButton(report, 'Top pages')
  await pagesTabButton.scrollIntoViewIfNeeded()
  await expect(pagesTabButton).toHaveAttribute('data-active', 'true')

  await detailsLink(report).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Top pages' })
  ).toBeVisible()

  await expectHeaders(modal(page), [
    'Page url',
    /Visitors/,
    /Pageviews/,
    /Bounce rate/,
    /Time on page/,
    /Scroll depth/
  ])

  await test.step('displays 100 entries on a single page', async () => {
    const pageRows = Array(100)
      .fill()
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
      .fill()
      .map((_, idx) => {
        return `/page${idx + 1}/foo`
      })

    await expectRows(modal(page), pageRows)
  })

  const searchInput = modal(page).locator('input[type=text]')

  await test.step('filters when using search', async () => {
    await searchInput.fill('page9')

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

    await expect(searchInput).toHaveValue('')

    const pageRows = Array(100)
      .fill()
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
    await page.goto('/' + domain + '?f=is,goal,create_site')

    const pagesTabButton = tabButton(report, 'Conversion pages')
    await pagesTabButton.scrollIntoViewIfNeeded()
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
      'Page url',
      /Total visitors/,
      /Conversions/,
      /CR/
    ])

    await expectRows(modal(page), ['/'])

    await expectMetricValues(modal(page), '/', ['2', '1', '50%'])

    await closeModalButton(page).click()
  })

  await test.step('revenue goal filter applied', async () => {
    await page.goto('/' + domain + '?f=is,goal,purchase')

    const pagesTabButton = tabButton(report, 'Conversion pages')
    await pagesTabButton.scrollIntoViewIfNeeded()
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
      'Page url',
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
      }
    ]
  })

  await page.goto('/' + domain)

  const report = page.getByTestId('report-locations')

  await test.step('map tab', async () => {
    const mapTabButton = tabButton(report, 'Map')
    await mapTabButton.scrollIntoViewIfNeeded()
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

    await expectRows(report, [/Harjumaa/, /Tartumaa/, /Mazovia/])

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

    await expectRows(modal(page), [/Harjumaa/, /Tartumaa/, /Mazovia/])

    await expectMetricValues(modal(page), 'Harjumaa', ['1'])

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

    await expectRows(report, [/Tartu/, /Tallinn/, /Warsaw/])

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

    await expectRows(modal(page), [/Tartu/, /Tallinn/, /Warsaw/])

    await expectMetricValues(modal(page), 'Tartu', ['1'])

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

  await page.goto('/' + domain)

  const report = page.getByTestId('report-devices')

  const browsersTabButton = tabButton(report, 'Browsers')

  await test.step('browsers tab', async () => {
    await browsersTabButton.scrollIntoViewIfNeeded()
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
