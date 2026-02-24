import { test, expect } from '@playwright/test'
import { setupSite, populateStats } from '../fixtures.ts'

const tabButton = (page, label) =>
  page.getByTestId('tab-button').filter({ hasText: label })

const expectHeaders = async (report, headers) =>
  expect(report.getByTestId('report-header')).toHaveText(headers)

const expectRows = async (report, labels) =>
  expect(report.getByTestId('report-row').getByRole('link')).toHaveText(labels)

const rowLink = (report, label) =>
  report.getByTestId('report-row').filter({ hasText: label }).getByRole('link')

const expectMetricValues = async (report, label, values) =>
  expect(
    report
      .getByTestId('report-row')
      .filter({ hasText: label })
      .getByTestId('metric-value')
  ).toHaveText(values)

const dropdown = (report) => report.getByTestId('dropdown-items')

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

  await test.step('clicking sources entry shows referrers', async () => {
    await rowLink(report, 'DuckDuckGo').click()
    const referrersReport = page.getByTestId('report-referrers')
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

    await page
      .getByRole('button', { name: 'Remove filter: Source is DuckDuckGo' })
      .click()
  })

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

  await test.step('browser versions', async () => {
    await rowLink(report, 'Firefox').click()

    await expect(page).toHaveURL(/f=is,browser,Firefox/)

    await expect(browsersTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Browser version', 'Visitors'])

    await expectRows(report, ['Firefox 98'])

    await expectMetricValues(report, 'Firefox 98', ['1', '100%'])

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

  await test.step('operating system versions', async () => {
    await rowLink(report, 'Windows').click()

    await expect(page).toHaveURL(/f=is,os,Windows/)

    await expect(osTabButton).toHaveAttribute('data-active', 'true')

    await expectHeaders(report, ['Operating system version', 'Visitors'])

    await page
      .getByRole('button', { name: 'Remove filter: Operating system is Windows' })
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
})
