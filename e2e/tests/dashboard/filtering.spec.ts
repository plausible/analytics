import { test, expect, Page } from '@playwright/test'
import { setupSite, populateStats, addPageviewGoal } from '../fixtures'
import {
  filterButton,
  filterItemButton,
  openFilterSubmenuItem,
  openPropertyKeys,
  propertyKeySearch,
  propertyKeyOption,
  filterPill,
  filterPillValuesButton,
  filterPillOperatorButton,
  filterOperatorOption,
  filterValueSearch,
  filterValueOption,
  pickFilterValue,
  closeFilterEditor
} from '../test-utils'

test.describe('page filtering tests', () => {
  const openPageFilter = (page: Page, item: string) =>
    openFilterSubmenuItem(page, 'Page', item)

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await filterButton(page).click()
    await openPageFilter(page, 'Page')

    await expect(filterPill(page, 'Page is')).toBeVisible()
    await expect(filterValueSearch(page)).toBeFocused()

    await filterValueSearch(page).fill('page')

    await expect(filterValueOption(page, '/page1')).toBeVisible()
    await expect(filterValueOption(page, '/page2')).toBeVisible()
    await expect(filterValueOption(page, '/page3')).toBeVisible()
    await expect(page).not.toHaveURL(/f=/)

    await filterValueSearch(page).fill('/page1')

    await expect(filterValueOption(page, '/page1')).toBeVisible()
    await expect(filterValueOption(page, '/page2')).toBeHidden()

    await filterValueOption(page, '/page1').click()

    await expect(page).toHaveURL(/f=is,page,\/page1/)
    await expect(filterValueOption(page, '/page1')).toHaveAttribute(
      'aria-selected',
      'true'
    )

    await closeFilterEditor(page)

    await expect(
      filterPillValuesButton(page, 'Page is /page1')
    ).toHaveAttribute('title', 'Page is /page1')
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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step("'is not' operator", async () => {
      await filterButton(page).click()
      await openPageFilter(page, 'Page')

      await filterPillOperatorButton(page, 'Page is').click()
      await filterOperatorOption(page, 'is not').click()
      await pickFilterValue(page, { search: 'page', value: '/page1' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Page is not /page1')).toBeVisible()

      await expect(page).toHaveURL(/f=is_not,page,\/page1/)

      await page
        .getByRole('button', { name: 'Remove filter: Page is not /page1' })
        .click()

      await expect(page).not.toHaveURL(/f=is_not,page,\/page1/)
    })

    await test.step("'contains' operator", async () => {
      await filterButton(page).click()
      await openPageFilter(page, 'Page')

      await filterPillOperatorButton(page, 'Page is').click()
      await filterOperatorOption(page, 'contains').click()
      await pickFilterValue(page, {
        search: 'page1',
        value: "Filter by 'page1'"
      })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Page contains page1')).toBeVisible()

      await expect(page).toHaveURL(/f=contains,page,page1/)

      await page
        .getByRole('button', { name: 'Remove filter: Page contains page1' })
        .click()

      await expect(page).not.toHaveURL(/f=contains,page,page1/)
    })

    await test.step("'does not contain' operator", async () => {
      await filterButton(page).click()
      await openPageFilter(page, 'Page')

      await filterPillOperatorButton(page, 'Page is').click()
      await filterOperatorOption(page, 'does not contain').click()
      await pickFilterValue(page, {
        search: 'page1',
        value: "Filter by 'page1'"
      })
      await closeFilterEditor(page)

      await expect(
        filterPill(page, 'Page does not contain page1')
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
      await openPageFilter(page, 'Page')

      await pickFilterValue(page, { search: 'page', value: '/page2' })
      await pickFilterValue(page, { value: '/page3' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Page is /page2 or /page3')).toBeVisible()

      await expect(page).toHaveURL(/f=is,page,\/page2,\/page3/)
    })

    await test.step('editing the values and the operator of a filter', async () => {
      await filterPillValuesButton(page, 'Page is /page2 or /page3').click()

      await expect(filterValueOption(page, '/page2')).toHaveAttribute(
        'aria-selected',
        'true'
      )
      await filterValueOption(page, '/page2').click()
      await expect(page).toHaveURL(/f=is,page,\/page3(&|$)/)

      await closeFilterEditor(page)
      await expect(filterPill(page, 'Page is /page3')).toBeVisible()

      await filterPillOperatorButton(page, 'Page is /page3').click()
      await filterOperatorOption(page, 'is not').click()

      await expect(filterPill(page, 'Page is not /page3')).toBeVisible()
      await expect(page).toHaveURL(/f=is_not,page,\/page3/)
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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await filterButton(page).click()
    await openPageFilter(page, 'Entry page')

    await pickFilterValue(page, { search: 'page', value: '/page1' })
    await closeFilterEditor(page)

    await expect(filterPill(page, 'Entry page is /page1')).toBeVisible()

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await filterButton(page).click()
    await openPageFilter(page, 'Exit page')

    await pickFilterValue(page, { search: 'page', value: '/page3' })
    await closeFilterEditor(page)

    await expect(filterPill(page, 'Exit page is /page3')).toBeVisible()

    await expect(page).toHaveURL(/f=is,exit_page,\/page3/)
  })
})

test.describe('hostname filtering tests', () => {
  const hostnameFilterButton = (page: Page) =>
    filterItemButton(page, 'Hostname')

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await filterButton(page).click()
    await hostnameFilterButton(page).click()

    await pickFilterValue(page, { search: 'one', value: 'one.example.com' })
    await closeFilterEditor(page)

    await expect(filterPill(page, 'Hostname is one.example.com')).toBeVisible()

    await expect(page).toHaveURL(/f=is,hostname,one.example.com/)
  })
})

test.describe('acquisition filtering tests', () => {
  const openSourceFilter = (page: Page, item: string) =>
    openFilterSubmenuItem(page, 'Source', item)

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step('filtering by source', async () => {
      await filterButton(page).click()
      await openSourceFilter(page, 'Source')

      await pickFilterValue(page, { search: 'goog', value: 'Google' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Source is Google')).toBeVisible()

      await expect(page).toHaveURL(/f=is,source,Google/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Source is Google'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,source,Google/)
    })

    await test.step('filtering by channel', async () => {
      await filterButton(page).click()
      await openSourceFilter(page, 'Channel')

      await pickFilterValue(page, { search: 'paid', value: 'Paid Search' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Channel is Paid Search')).toBeVisible()

      await expect(page).toHaveURL(/f=is,channel,Paid%20Search/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Channel is Paid Search'
        })
        .click()

      await expect(page).not.toHaveURL(/f=is,channel,Paid%20Search/)
    })

    await test.step('filtering by referrer URL', async () => {
      await filterButton(page).click()
      await openSourceFilter(page, 'Referrer URL')

      await pickFilterValue(page, {
        search: 'guard',
        value: 'https://theguardian.com'
      })
      await closeFilterEditor(page)

      await expect(
        filterPill(page, 'Referrer URL is https://theguardian.com')
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

  const openUtmFilter = (page: Page, item: string) =>
    openFilterSubmenuItem(page, 'UTM tags', item)

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    const utmSteps = [
      { item: 'UTM medium', key: 'utm_medium', search: 'soc', value: 'social' },
      {
        item: 'UTM source',
        key: 'utm_source',
        search: 'hunt',
        value: 'producthunt'
      },
      {
        item: 'UTM campaign',
        key: 'utm_campaign',
        search: 'ads',
        value: 'ads'
      },
      { item: 'UTM term', key: 'utm_term', search: 'pos', value: 'post' },
      {
        item: 'UTM content',
        key: 'utm_content',
        search: 'web',
        value: 'website'
      }
    ]

    for (const { item, key, search, value } of utmSteps) {
      await test.step(`filtering by ${item}`, async () => {
        const pillName = `${item} is ${value}`
        const url = new RegExp(`f=is,${key},${value}`)

        await filterButton(page).click()
        await openUtmFilter(page, item)

        await pickFilterValue(page, { search, value })
        await closeFilterEditor(page)

        await expect(filterPill(page, pillName)).toBeVisible()

        await expect(page).toHaveURL(url)

        await page
          .getByRole('button', { name: `Remove filter: ${pillName}` })
          .click()

        await expect(page).not.toHaveURL(url)
      })
    }
  })
})

test.describe('location filtering tests', () => {
  const openLocationFilter = (page: Page, item: string) =>
    openFilterSubmenuItem(page, 'Location', item)

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
          city_geoname_id: 588_409,
          browser: 'Chrome'
        }
      ]
    })

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step('filtering by country', async () => {
      await filterButton(page).click()
      await openLocationFilter(page, 'Country')

      await pickFilterValue(page, { search: 'est', value: 'Estonia' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Country is Estonia')).toBeVisible()

      await expect(page).toHaveURL(/f=is,country,EE/)
    })

    await test.step('filtering by region', async () => {
      await filterButton(page).click()
      await openLocationFilter(page, 'Region')

      await pickFilterValue(page, { search: 'har', value: 'Harjumaa' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Region is Harjumaa')).toBeVisible()

      await expect(page).toHaveURL(/f=is,region,EE-37/)
      await expect(page).toHaveURL(/f=is,country,EE/)
    })

    await test.step('filtering by city', async () => {
      await filterButton(page).click()
      await openLocationFilter(page, 'City')

      await pickFilterValue(page, { value: 'Tallinn' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'City is Tallinn')).toBeVisible()

      await expect(page).toHaveURL(/f=is,city,588409/)
      await expect(page).toHaveURL(/f=is,region,EE-37/)
      await expect(page).toHaveURL(/f=is,country,EE/)
    })
  })
})

test.describe('screen size filtering tests', () => {
  const screenSizeFilterButton = (page: Page) =>
    filterItemButton(page, 'Screen size')

  test('filtering by screen size', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', screen_size: 'Desktop' },
        { name: 'pageview', screen_size: 'Mobile' }
      ]
    })

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await filterButton(page).click()
    await screenSizeFilterButton(page).click()

    // When testing via test.e2e.ui, it shows there are no
    // suggestions found but there are 2 pageview in the top stats.
    // When navigating live via `MIX_ENV=e2e_test iex -S mix`,
    // all works fine. Puzzling.
    await pickFilterValue(page, { search: 'mob', value: 'Mobile' })
    await closeFilterEditor(page)

    await expect(filterPill(page, 'Screen size is Mobile')).toBeVisible()

    await expect(page).toHaveURL(/f=is,screen,Mobile/)
  })
})

test.describe('browser filtering tests', () => {
  const openBrowserFilter = (page: Page, item: string) =>
    openFilterSubmenuItem(page, 'Browser', item)

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step('filtering by browser type', async () => {
      await filterButton(page).click()
      await openBrowserFilter(page, 'Browser')

      await pickFilterValue(page, { search: 'chrom', value: 'Chrome' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Browser is Chrome')).toBeVisible()

      await expect(page).toHaveURL(/f=is,browser,Chrome/)
    })

    await test.step('filtering by browser version', async () => {
      await filterButton(page).click()
      await openBrowserFilter(page, 'Browser version')

      await pickFilterValue(page, { search: '14', value: '14.0.7' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Browser version is 14.0.7')).toBeVisible()

      await expect(page).toHaveURL(/f=is,browser_version,14\.0\.7/)
      await expect(page).toHaveURL(/f=is,browser,Chrome/)
    })
  })
})

test.describe('operating system filtering tests', () => {
  const openOperatingSystemFilter = (page: Page, item: string) =>
    openFilterSubmenuItem(page, 'Operating system', item)

  test('filtering by operating system', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          name: 'pageview',
          operating_system: 'Windows',
          operating_system_version: '11',
          browser: 'Chrome',
          browser_version: '14.0.7'
        },
        {
          name: 'pageview',
          operating_system: 'MacOS',
          operating_system_version: '10.15'
        }
      ]
    })

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step('filtering by operating system type', async () => {
      await filterButton(page).click()
      await openOperatingSystemFilter(page, 'Operating system')

      // The same problem as in the case of screen size filter test.
      await pickFilterValue(page, { value: 'Windows' })
      await closeFilterEditor(page)

      await expect(
        filterPill(page, 'Operating system is Windows')
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,os,Windows/)
    })

    await test.step('filtering by operating system version', async () => {
      await filterButton(page).click()
      await openOperatingSystemFilter(page, 'Operating system version')

      await pickFilterValue(page, { value: '11' })
      await closeFilterEditor(page)

      await expect(
        filterPill(page, 'Operating system version is 11')
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,os_version,11/)
      await expect(page).toHaveURL(/f=is,os,Windows/)
    })
  })
})

test.describe('goal filtering tests', () => {
  const goalFilterButton = (page: Page) => filterItemButton(page, 'Goal')

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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step('single goal filter', async () => {
      await filterButton(page).click()
      await goalFilterButton(page).click()

      await pickFilterValue(page, { search: 'page1', value: 'Visit /page1' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Goal is Visit /page1')).toBeVisible()

      await expect(page).toHaveURL(/f=is,goal,Visit%20\/page1/)
    })

    await test.step('multiple goal filters', async () => {
      await filterButton(page).click()
      await goalFilterButton(page).click()

      await expect(filterPill(page, 'Goal is')).toBeVisible()

      await filterPillOperatorButton(page, 'Goal is').click()
      await filterOperatorOption(page, 'is not').click()
      await pickFilterValue(page, { search: 'page2', value: 'Visit /page2' })
      await closeFilterEditor(page)

      await expect(filterPill(page, 'Goal is Visit /page1')).toBeVisible()
      await expect(filterPill(page, 'Goal is not Visit /page2')).toBeVisible()

      await expect(page).toHaveURL(/f=is,goal,Visit%20\/page1/)
      await expect(page).toHaveURL(/f=has_not_done,goal,Visit%20\/page2/)
    })
  })
})

test.describe('property filtering tests', () => {
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

    await page.goto('/' + domain, { waitUntil: 'commit' })

    await test.step('single property filter', async () => {
      await filterButton(page).click()
      await openPropertyKeys(page)

      await propertyKeySearch(page).fill('logged')
      await propertyKeyOption(page, 'logged_in').click()

      await expect(filterPill(page, "Property 'logged_in' is")).toBeVisible()

      await pickFilterValue(page, { search: 'false', value: 'false' })
      await closeFilterEditor(page)

      await expect(
        filterPill(page, "Property 'logged_in' is false")
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,props:logged_in,false/)
    })

    await test.step('multiple property filters', async () => {
      await filterButton(page).click()
      await openPropertyKeys(page)

      await propertyKeySearch(page).fill('logged')
      await expect(propertyKeyOption(page, 'logged_in')).toHaveAttribute(
        'aria-disabled',
        'true'
      )

      await propertyKeySearch(page).fill('browser')
      await propertyKeyOption(page, 'browser_language').click()

      await filterPillOperatorButton(
        page,
        "Property 'browser_language' is"
      ).click()
      await filterOperatorOption(page, 'is not').click()
      await pickFilterValue(page, { search: 'US', value: 'en_US' })
      await closeFilterEditor(page)

      await expect(
        filterPill(page, "Property 'logged_in' is false")
      ).toBeVisible()

      await expect(
        filterPill(page, "Property 'browser_language' is not en_US")
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,props:logged_in,false/)
      await expect(page).toHaveURL(/f=is_not,props:browser_language,en_US/)
    })
  })
})
