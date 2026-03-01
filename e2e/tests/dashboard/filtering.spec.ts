import { test, expect } from '@playwright/test'
import { setupSite, populateStats, addPageviewGoal } from '../fixtures.ts'
import {
  filterButton,
  applyFilterButton,
  filterRow,
  suggestedItem,
  filterOperator,
  filterOperatorOption
} from '../test-utils.ts'

test.describe('page filtering tests', () => {
  const pageFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Page' })

  test('filtering by page with detailed behavior test', async ({
    page,
    request
  }) => {
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

    const pageFilterRow = filterRow(page, 'page')
    const pageInput = page.getByPlaceholder('Select a Page')

    await filterButton(page).click()
    await pageFilterButton(page).click()

    await expect(
      page.getByRole('heading', { name: 'Filter by Page' })
    ).toBeVisible()

    await expect(applyFilterButton(page, { disabled: true })).toBeVisible()
    await pageInput.fill('page')

    await expect(suggestedItem(pageFilterRow, '/page1')).toBeVisible()
    await expect(suggestedItem(pageFilterRow, '/page2')).toBeVisible()
    await expect(suggestedItem(pageFilterRow, '/page3')).toBeVisible()
    await expect(applyFilterButton(page, { disabled: true })).toBeVisible()

    await pageInput.fill('/page1')

    await expect(suggestedItem(pageFilterRow, '/page1')).toBeVisible()
    await expect(applyFilterButton(page, { disabled: true })).toBeVisible()

    await suggestedItem(pageFilterRow, '/page1').click()
    await expect(applyFilterButton(page)).toBeVisible()

    await applyFilterButton(page).click()

    await expect(page).toHaveURL(/f=is,page,\/page1/)

    await expect(
      page.getByRole('link', { name: 'Page is /page1' })
    ).toHaveAttribute('title', 'Edit filter: Page is /page1')
  })

  test('filtering by page using different operators', async ({
    page,
    request
  }) => {
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

    const pageFilterRow = filterRow(page, 'page')
    const pageInput = page.getByPlaceholder('Select a Page')

    await test.step("'is not' operator", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await filterOperator(pageFilterRow).click()
      await filterOperatorOption(pageFilterRow, 'is not').click()
      await pageInput.fill('page')
      await suggestedItem(pageFilterRow, '/page1').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page is not /page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is_not,page,\/page1/)

      await page
        .getByRole('button', { name: 'Remove filter: Page is not /page1' })
        .click()

      await expect(page).not.toHaveURL(/f=is_not,page,\/page1/)
    })

    await test.step("'contains' operator", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await filterOperator(pageFilterRow).click()
      await filterOperatorOption(pageFilterRow, 'contains').click()
      await pageInput.fill('page1')
      await suggestedItem(pageFilterRow, "Filter by 'page1'").click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page contains page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=contains,page,page1/)

      await page
        .getByRole('button', { name: 'Remove filter: Page contains page1' })
        .click()

      await expect(page).not.toHaveURL(/f=contains,page,page1/)
    })

    await test.step("'does not contain' operator", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await filterOperator(pageFilterRow).click()
      await filterOperatorOption(pageFilterRow, 'does not contain').click()
      await pageInput.fill('page1')
      await suggestedItem(pageFilterRow, "Filter by 'page1'").click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page does not contain page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=contains_not,page,page1/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Page does not contain page1'
        })
        .click()

      await expect(page).not.toHaveURL(/f=contains_not,page,page1/)
    })

    await test.step("'is' operator with multiple choices", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await pageInput.fill('page')
      await suggestedItem(pageFilterRow, '/page2').click()
      await pageInput.fill('page')
      await suggestedItem(pageFilterRow, '/page3').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page is /page2 or /page3' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,page,\/page2,\/page3/)
    })
  })

  test('filtering by entry page', async ({ page, request }) => {
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

    const entryPageFilterRow = filterRow(page, 'entry_page')
    const entryPageInput = page.getByPlaceholder('Select an Entry Page')

    await filterButton(page).click()
    await pageFilterButton(page).click()

    await entryPageInput.fill('page')
    await suggestedItem(entryPageFilterRow, '/page1').click()

    await applyFilterButton(page).click()

    await expect(
      page.getByRole('link', { name: 'Entry page is /page1' })
    ).toBeVisible()

    await expect(page).toHaveURL(/f=is,entry_page,\/page1/)
  })

  test('filtering by exit page', async ({ page, request }) => {
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

    const exitPageFilterRow = filterRow(page, 'exit_page')
    const exitPageInput = page.getByPlaceholder('Select an Exit Page')

    await filterButton(page).click()
    await pageFilterButton(page).click()

    await exitPageInput.fill('page')
    await suggestedItem(exitPageFilterRow, '/page3').click()

    await applyFilterButton(page).click()

    await expect(
      page.getByRole('link', { name: 'Exit page is /page3' })
    ).toBeVisible()

    await expect(page).toHaveURL(/f=is,exit_page,\/page3/)
  })
})

test.describe('hostname filtering tests', () => {
  const hostnameFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Hostname' })

  test('filtering by hostname', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', hostname: 'one.example.com' },
        { name: 'pageview', hostname: 'two.example.com' }
      ]
    })

    await page.goto('/' + domain)

    const hostnameFilterRow = filterRow(page, 'hostname')
    const hostnameInput = page.getByPlaceholder('Select a Hostname')

    await filterButton(page).click()
    await hostnameFilterButton(page).click()

    await hostnameInput.fill('one')
    await suggestedItem(hostnameFilterRow, 'one.example.com').click()

    await applyFilterButton(page).click()

    await expect(
      page.getByRole('link', { name: 'Hostname is one.example.com' })
    ).toBeVisible()

    await expect(page).toHaveURL(/f=is,hostname,one.example.com/)
  })
})

test.describe('acquisition filtering tests', () => {
  const sourceFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Source' })

  test('filtering by source information', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', referrer_source: 'Google', utm_source: 'Adwords' },
        { name: 'pageview', referrer_source: 'Facebook', utm_source: 'fb' },
        { name: 'pageview', referrer: 'https://theguardian.com' }
      ]
    })

    await page.goto('/' + domain)

    await test.step('filtering by source', async () => {
      const sourceFilterRow = filterRow(page, 'source')
      const sourceInput = page.getByPlaceholder('Select a Source')

      await filterButton(page).click()
      await sourceFilterButton(page).click()

      await sourceInput.fill('goog')
      await suggestedItem(sourceFilterRow, 'Google').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Source is Google' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,source,Google/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Source is Google'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,source,Google/)
    })

    await test.step('filtering by channel', async () => {
      const channelFilterRow = filterRow(page, 'channel')
      const channelInput = page.getByPlaceholder('Select a Channel')

      await filterButton(page).click()
      await sourceFilterButton(page).click()

      await channelInput.fill('paid')
      await suggestedItem(channelFilterRow, 'Paid Search').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Channel is Paid Search' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,channel,Paid%20Search/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Channel is Paid Search'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,channel,Paid%20Search/)
    })

    await test.step('filtering by referrer URL', async () => {
      const referrerFilterRow = filterRow(page, 'referrer')
      const referrerInput = page.getByPlaceholder('Select a Referrer URL')

      await filterButton(page).click()
      await sourceFilterButton(page).click()

      await referrerInput.fill('guard')
      await suggestedItem(referrerFilterRow, 'https://theguardian.com').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', {
          name: 'Referrer URL is https://theguardian.com'
        })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,referrer,https:\/\/theguardian\.com/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Referrer URL is https://theguardian.com'
        })
        .click()

      await expect(page).not.toHaveURL(
        /f=is,referrer,https:\/\/theguardian\.com/
      )
    })
  })

  const utmTagsFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'UTM Tags' })

  test('filtering by UTM tags', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', utm_medium: 'social' },
        { name: 'pageview', utm_source: 'producthunt' },
        { name: 'pageview', utm_campaign: 'ads' },
        { name: 'pageview', utm_term: 'post' },
        { name: 'pageview', utm_content: 'website' }
      ]
    })

    await page.goto('/' + domain)

    await test.step('filtering by UTM medium', async () => {
      const utmMediumFilterRow = filterRow(page, 'utm_medium')
      const utmMediumInput = page.getByPlaceholder('Select a UTM Medium')

      await filterButton(page).click()
      await utmTagsFilterButton(page).click()

      await utmMediumInput.fill('soc')
      await suggestedItem(utmMediumFilterRow, 'social').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'UTM Medium is social' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,utm_medium,social/)

      await page
        .getByRole('button', {
          name: 'Remove filter: UTM Medium is social'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,utm_medium,social/)
    })

    await test.step('filtering by UTM source', async () => {
      const utmSourceFilterRow = filterRow(page, 'utm_source')
      const utmSourceInput = page.getByPlaceholder('Select a UTM Source')

      await filterButton(page).click()
      await utmTagsFilterButton(page).click()

      await utmSourceInput.fill('hunt')
      await suggestedItem(utmSourceFilterRow, 'producthunt').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'UTM Source is producthunt' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,utm_source,producthunt/)

      await page
        .getByRole('button', {
          name: 'Remove filter: UTM Source is producthunt'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,utm_source,producthunt/)
    })

    await test.step('filtering by UTM campaign', async () => {
      const utmCampaignFilterRow = filterRow(page, 'utm_campaign')
      const utmCampaignInput = page.getByPlaceholder('Select a UTM Campaign')

      await filterButton(page).click()
      await utmTagsFilterButton(page).click()

      await utmCampaignInput.fill('ads')
      await suggestedItem(utmCampaignFilterRow, 'ads').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'UTM Campaign is ads' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,utm_campaign,ads/)

      await page
        .getByRole('button', {
          name: 'Remove filter: UTM Campaign is ads'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,utm_campaign,ads/)
    })

    await test.step('filtering by UTM term', async () => {
      const utmTermFilterRow = filterRow(page, 'utm_term')
      const utmTermInput = page.getByPlaceholder('Select a UTM Term')

      await filterButton(page).click()
      await utmTagsFilterButton(page).click()

      await utmTermInput.fill('pos')
      await suggestedItem(utmTermFilterRow, 'post').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'UTM Term is post' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,utm_term,post/)

      await page
        .getByRole('button', {
          name: 'Remove filter: UTM Term is post'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,utm_term,post/)
    })

    await test.step('filtering by UTM content', async () => {
      const utmContentFilterRow = filterRow(page, 'utm_content')
      const utmContentInput = page.getByPlaceholder('Select a UTM Content')

      await filterButton(page).click()
      await utmTagsFilterButton(page).click()

      await utmContentInput.fill('web')
      await suggestedItem(utmContentFilterRow, 'website').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'UTM Content is website' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,utm_content,website/)

      await page
        .getByRole('button', {
          name: 'Remove filter: UTM Content is website'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,utm_content,website/)
    })
  })
})

test.describe('location filtering tests', () => {
  const locationFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Location' })

  test('filtering by location', async ({ page, request }) => {
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
        }
      ]
    })

    await page.goto('/' + domain)

    await test.step('filtering by country', async () => {
      const countryFilterRow = filterRow(page, 'country')
      const countryInput = page.getByPlaceholder('Select a Country')

      await filterButton(page).click()
      await locationFilterButton(page).click()

      await countryInput.fill('est')
      await suggestedItem(countryFilterRow, 'Estonia').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Country is Estonia' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,country,EE/)
    })

    await test.step('filtering by region', async () => {
      const regionFilterRow = filterRow(page, 'region')
      const regionInput = page.getByPlaceholder('Select a Region')

      await filterButton(page).click()
      await locationFilterButton(page).click()

      await regionInput.fill('har')
      await suggestedItem(regionFilterRow, 'Harjumaa').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Region is Harjumaa' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,region,EE-37/)
      await expect(page).toHaveURL(/f=is,country,EE/)
    })

    await test.step('filtering by city', async () => {
      const cityFilterRow = filterRow(page, 'city')
      const cityInput = page.getByPlaceholder('Select a City')

      await filterButton(page).click()
      await locationFilterButton(page).click()

      await cityInput.click()
      await suggestedItem(cityFilterRow, 'Tallinn').click()

      await applyFilterButton(page).click()

      await page
        .getByRole('button', { name: 'See 1 more filter and actions' })
        .click()

      await expect(
        page.getByRole('link', { name: 'City is Tallinn' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,city,588409/)
      await expect(page).toHaveURL(/f=is,region,EE-37/)
      await expect(page).toHaveURL(/f=is,country,EE/)
    })
  })
})

test.describe('screen size filtering tests', () => {
  const screenSizeFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Screen size' })

  test.fixme('filtering by screen size', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', screen_size: 'Desktop' },
        { name: 'pageview', screen_size: 'Mobile' }
      ]
    })

    await page.goto('/' + domain)

    const screenSizeFilterRow = filterRow(page, 'screen_size')
    const screenSizeInput = page.getByPlaceholder('Select a Screen size')

    await filterButton(page).click()
    await screenSizeFilterButton(page).click()

    // When testing via test.e2e.ui, it shows there are no
    // suggestions found but there are 2 pageview in the top stats.
    // When navigating live via `MIX_ENV=e2e_test iex -S mix`,
    // all works fine. Puzzling.
    await screenSizeInput.click()
    await suggestedItem(screenSizeFilterRow, 'Mobile').click()

    await applyFilterButton(page).click()

    await expect(
      page.getByRole('link', { name: 'Screen size is Mobile' })
    ).toBeVisible()

    await expect(page).toHaveURL(/f=is,screen_size,Mobile/)
  })
})

test.describe('browser filtering tests', () => {
  const browserFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Browser' })

  test('filtering by browser', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', browser: 'Chrome', browser_version: '14.0.7' },
        { name: 'pageview', browser: 'Firefox', browser_version: '98' }
      ]
    })

    await page.goto('/' + domain)

    await test.step('filtering by browser type', async () => {
      const browserFilterRow = filterRow(page, 'browser')
      const browserInput = page.getByPlaceholder('Select a Browser', {
        exact: true
      })

      await filterButton(page).click()
      await browserFilterButton(page).click()

      await browserInput.fill('chrom')
      await suggestedItem(browserFilterRow, 'Chrome').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Browser is Chrome' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,browser,Chrome/)
    })

    await test.step('filtering by browser version', async () => {
      const browserVersionFilterRow = filterRow(page, 'browser_version')
      const browserVersionInput = page.getByPlaceholder(
        'Select a Browser Version'
      )

      await filterButton(page).click()
      await browserFilterButton(page).click()

      await browserVersionInput.fill('14')
      await suggestedItem(browserVersionFilterRow, '14.0.7').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Browser version is 14.0.7' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,browser_version,14\.0\.7/)
      await expect(page).toHaveURL(/f=is,browser,Chrome/)
    })
  })
})

test.describe('operating system filtering tests', () => {
  const operatingSystemFilterButton = (page) =>
    page
      .getByTestId('filtermenu')
      .getByRole('link', { name: 'Operating system' })

  test.fixme('filtering by operating system', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          name: 'pageview',
          operating_system: 'Windows',
          operating_system_version: '11'
        },
        {
          name: 'pageview',
          operating_system: 'MacOS',
          operating_system_version: '10.15'
        }
      ]
    })

    await page.goto('/' + domain)

    await test.step('filtering by operating system type', async () => {
      const operatingSystemFilterRow = filterRow(page, 'operating_system')
      const operatingSystemInput = page.getByPlaceholder(
        'Select an Operating system',
        { exact: true }
      )

      await filterButton(page).click()
      await operatingSystemFilterButton(page).click()

      // The same problem as in the case of screen size filter test.
      await operatingSystemInput.click()
      await suggestedItem(operatingSystemFilterRow, 'Windows').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Operating System is Windows' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,operating_system,Windows/)
    })

    await test.step('filtering by operating system version', async () => {
      const operatingSystemVersionFilterRow = filterRow(
        page,
        'operating_system_version'
      )
      const operatingSystemVersionInput = page.getByPlaceholder(
        'Select an Operating system version'
      )

      await filterButton(page).click()
      await operatingSystemFilterButton(page).click()

      await operatingSystemVersionInput.click()
      await suggestedItem(operatingSystemVersionFilterRow, '11').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Operating system version is 11' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,operating_system_version,11/)
      await expect(page).toHaveURL(/f=is,operating_system,Windows/)
    })
  })
})

test.describe('goal filtering tests', () => {
  const goalFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Goal' })

  test('filtering by goals', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', pathname: '/page1' },
        { name: 'pageview', pathname: '/page2' }
      ]
    })

    await addPageviewGoal({ page, domain, pathname: '/page1' })
    await addPageviewGoal({ page, domain, pathname: '/page2' })

    await page.goto('/' + domain)

    const goalFilterRow = filterRow(page, 'goal')
    const goalInput = goalFilterRow.getByPlaceholder('Select a Goal')

    await test.step('single goal filter', async () => {
      await filterButton(page).click()
      await goalFilterButton(page).click()

      await goalInput.fill('page1')
      await suggestedItem(goalFilterRow, 'Visit /page1').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Goal is Visit /page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,goal,Visit%20\/page1/)
    })

    const goalFilterRow2 = filterRow(page, 'goal1')
    const goalInput2 = goalFilterRow2.getByPlaceholder('Select a Goal')

    await test.step('multiple goal filters', async () => {
      await page.getByRole('link', { name: 'Goal is Visit /page1' }).click()

      await page.getByText('+ Add another').click()

      await filterOperator(goalFilterRow2).click()
      await filterOperatorOption(goalFilterRow2, 'is not').click()

      await goalInput2.fill('page2')
      await suggestedItem(goalFilterRow2, 'Visit /page2').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Goal is Visit /page1' })
      ).toBeVisible()

      await expect(
        page.getByRole('link', { name: 'Goal is not Visit /page2' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,goal,Visit%20\/page1/)
      await expect(page).toHaveURL(/f=has_not_done,goal,Visit%20\/page2/)
    })
  })
})

test.describe('property filtering tests', () => {
  const propFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Property' })

  test('filtering by properties', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          name: 'pageview',
          'meta.key': ['logged_in', 'browser_language'],
          'meta.value': ['false', 'en_US']
        },
        {
          name: 'pageview',
          'meta.key': ['logged_in', 'browser_language'],
          'meta.value': ['true', 'es']
        }
      ]
    })

    await page.goto('/' + domain)

    const propFilterRow = filterRow(page, 'props')
    const propNameInput = propFilterRow.getByPlaceholder('Property')
    const propValueInput = propFilterRow.getByPlaceholder('Value')

    await test.step('single property filter', async () => {
      await filterButton(page).click()
      await propFilterButton(page).click()

      await propNameInput.fill('logged')
      await suggestedItem(propFilterRow, 'logged_in').click()
      await propValueInput.fill('false')
      await suggestedItem(propFilterRow, 'false').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Property logged_in is false' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,props:logged_in,false/)
    })

    const propFilterRow2 = filterRow(page, 'props1')
    const propNameInput2 = propFilterRow2.getByPlaceholder('Property')
    const propValueInput2 = propFilterRow2.getByPlaceholder('Value')

    await test.step('multiple property filters', async () => {
      await page
        .getByRole('link', { name: 'Property logged_in is false' })
        .click()

      await page.getByText('+ Add another').click()

      await propNameInput2.fill('browser')
      await suggestedItem(propFilterRow2, 'browser_language').click()
      await filterOperator(propFilterRow2).click()
      await filterOperatorOption(propFilterRow2, 'is not').click()
      await propValueInput2.fill('US')
      await suggestedItem(propFilterRow2, 'en_US').click()

      await applyFilterButton(page).click()

      await page
        .getByRole('button', { name: 'See 1 more filter and actions' })
        .click()

      await expect(
        page.getByRole('link', {
          name: 'Property logged_in is false'
        })
      ).toBeVisible()

      await expect(
        page.getByRole('link', {
          name: 'Property browser_language is not en_US'
        })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,props:logged_in,false/)
      await expect(page).toHaveURL(/f=is_not,props:browser_language,en_US/)
    })
  })
})
