import { test, expect, APIRequestContext, Page } from '@playwright/test'
import { setupSite, populateStats } from '../fixtures'
import {
  filterButton,
  filterItemButton,
  applyFilterButton,
  filterRow,
  suggestedItem,
  modal
} from '../test-utils'

const setupSiteAndStats = async ({
  page,
  request
}: {
  page: Page
  request: APIRequestContext
}) => {
  const context = await setupSite({ page, request })

  await populateStats({
    request,
    domain: context.domain,
    events: [
      {
        name: 'pageview',
        referrer_source: 'Google',
        utm_source: 'Adwords',
        utm_medium: 'email',
        utm_campaign: 'promo'
      },
      { name: 'pageview', referrer_source: 'Facebook', utm_source: 'fb' },
      { name: 'pageview', referrer: 'https://theguardian.com' }
    ]
  })

  return context
}

const segmentMenu = (page: Page) => page.getByTestId('segment-menu')

const sourceFilterButton = (page: Page) => filterItemButton(page, 'Source')
const utmTagsFilterButton = (page: Page) => filterItemButton(page, 'UTM tags')

const addSourceFilter = async (page: Page, sourceLabel: string) => {
  const sourceFilterRow = filterRow(page, 'source')
  const sourceInput = page.getByPlaceholder('Select a Source')

  await filterButton(page).click()
  await sourceFilterButton(page).click()

  await sourceInput.click()
  await suggestedItem(sourceFilterRow, sourceLabel).click()

  await applyFilterButton(page).click()

  const url = new RegExp(`f=is,source,${sourceLabel}`)
  await expect(page).toHaveURL(url)
}

const addUtmSourceFilter = async (page: Page, utmSource: string) => {
  const utmSourceFilterRow = filterRow(page, 'utm_source')
  const utmSourceInput = page.getByPlaceholder('Select a UTM Source')

  await filterButton(page).click()
  await utmTagsFilterButton(page).click()

  await utmSourceInput.click()
  await suggestedItem(utmSourceFilterRow, utmSource).click()

  await applyFilterButton(page).click()

  const url = new RegExp(`f=is,utm_source,${utmSource}`)
  await expect(page).toHaveURL(url)
}

const createPersonalSegment = async (page: Page, name: string) => {
  await page.getByRole('button', { name: 'See actions' }).click()

  await page.getByRole('link', { name: 'Save as segment' }).click()

  await modal(page).getByLabel('Segment name').fill(name)

  await modal(page).getByRole('button', { name: 'Save' }).click()

  await expect(page).toHaveURL(/f=is,segment,[0-9]+/)
}

test('saving a segment', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await test.step('creating personal segment using defaults', async () => {
    await addSourceFilter(page, 'Facebook')

    await page.getByRole('button', { name: 'See actions' }).click()

    await page.getByRole('link', { name: 'Save as segment' }).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Create segment' })
    ).toBeVisible()

    await expect(
      modal(page).getByPlaceholder('Source is Facebook')
    ).toHaveAccessibleName('Segment name')

    await expect(
      modal(page).getByRole('radio', { name: 'Personal segment' })
    ).toBeChecked()

    await modal(page).getByRole('button', { name: 'Save' }).click()

    await expect(page).toHaveURL(/f=is,segment,[0-9]+/)

    await expect(
      page.getByRole('link', { name: 'Segment is Source is Facebook' })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Segment is Source is Facebook'
      })
      .click()

    await filterButton(page).click()

    await expect(filterItemButton(page, 'Source is Facebook')).toBeVisible()

    await filterButton(page).click()
  })

  await test.step('creating a personal segment with a custom name', async () => {
    await addSourceFilter(page, 'Google')

    await page.getByRole('button', { name: 'See actions' }).click()

    await page.getByRole('link', { name: 'Save as segment' }).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Create segment' })
    ).toBeVisible()

    await modal(page).getByLabel('Segment name').fill('Traffic from Google')

    await expect(
      modal(page).getByRole('radio', { name: 'Personal segment' })
    ).toBeChecked()

    await modal(page).getByRole('button', { name: 'Save' }).click()

    await expect(page).toHaveURL(/f=is,segment,[0-9]+/)

    await expect(
      page.getByRole('link', { name: 'Segment is Traffic from Google' })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Segment is Traffic from Google'
      })
      .click()

    await filterButton(page).click()

    await expect(filterItemButton(page, 'Traffic from Google')).toBeVisible()
    await expect(filterItemButton(page, 'Source is Facebook')).toBeVisible()

    await filterButton(page).click()
  })

  await test.step('creating a site segment from more than one filter', async () => {
    await addSourceFilter(page, 'Google')
    await addUtmSourceFilter(page, 'Adwords')

    await page.getByRole('button', { name: 'See actions' }).click()

    await page.getByRole('link', { name: 'Save as segment' }).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Create segment' })
    ).toBeVisible()

    await expect(
      modal(page).getByPlaceholder('UTM source is Adwords and Source is Google')
    ).toHaveAccessibleName('Segment name')

    await modal(page).getByLabel('Segment name').fill('Ads from Google')

    const siteSegmentRadio = modal(page).getByRole('radio', {
      name: 'Site segment'
    })

    await siteSegmentRadio.click()

    await expect(siteSegmentRadio).toBeChecked()

    await modal(page).getByRole('button', { name: 'Save' }).click()

    await expect(page).toHaveURL(/f=is,segment,[0-9]+/)

    await expect(
      page.getByRole('link', { name: 'Segment is Ads from Google' })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Segment is Ads from Google'
      })
      .click()

    await filterButton(page).click()

    await expect(filterItemButton(page, 'Ads from Google')).toBeVisible()
    await expect(filterItemButton(page, 'Traffic from Google')).toBeVisible()
    await expect(filterItemButton(page, 'Source is Facebook')).toBeVisible()

    await filterButton(page).click()
  })
})

test('creating a segment from a combination of segment and a filter is not allowed', async ({
  page,
  request
}) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')
  await addUtmSourceFilter(page, 'Adwords')

  // Add UTM medium and campaign filters so Segment ends up as the 4th pill.
  // This ensures it overflows into "See more" regardless of viewport width
  const utmMediumFilterRow = filterRow(page, 'utm_medium')
  const utmCampaignFilterRow = filterRow(page, 'utm_campaign')

  await filterButton(page).click()
  await utmTagsFilterButton(page).click()
  await page.getByPlaceholder('Select a UTM Medium').click()
  await suggestedItem(utmMediumFilterRow, 'email').click()
  await applyFilterButton(page).click()

  await filterButton(page).click()
  await utmTagsFilterButton(page).click()
  await page.getByPlaceholder('Select a UTM Campaign').click()
  await suggestedItem(utmCampaignFilterRow, 'promo').click()
  await applyFilterButton(page).click()

  await expect(
    page.getByRole('link', { name: 'UTM source is Adwords' })
  ).toBeVisible()

  await page.getByRole('button', { name: /See.*more/ }).click()
  await expect(
    page.getByRole('link', { name: 'Segment is Traffic from Google' })
  ).toBeVisible()

  await expect(page).toHaveURL(/f=is,segment,[0-9]+/)
  await expect(page).toHaveURL(/f=is,utm_source,Adwords/)

  await expect(
    modal(page).getByRole('heading', { name: 'Create segment' })
  ).toBeHidden()
})

test('editing an existing segment', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await page
    .getByRole('link', { name: 'Segment is Traffic from Google' })
    .click()

  await expect(
    modal(page).getByRole('heading', { name: 'Traffic from Google' })
  ).toBeVisible()

  await modal(page).getByRole('link', { name: 'Edit segment' }).click()

  await addUtmSourceFilter(page, 'Adwords')

  await page.getByRole('link', { name: 'Update segment' }).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Update segment' })
  ).toBeVisible()

  await modal(page).getByLabel('Segment name').fill('Ads from Google')

  await modal(page).getByRole('button', { name: 'Save' }).click()

  await page.getByRole('link', { name: 'Segment is Ads from Google' }).click()

  await expect(modal(page)).toContainText('UTM source is Adwords')
  await expect(modal(page)).toContainText('Source is Google')

  await modal(page).getByRole('button', { name: 'Remove filter' }).click()

  await expect(page).not.toHaveURL(/f=is,segment,[0-9]+/)

  await filterButton(page).click()

  await expect(filterItemButton(page, 'Ads from Google')).toBeVisible()
  await expect(filterItemButton(page, 'Traffic from Google')).toBeHidden()
})

test('saving edited segment as new', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await page
    .getByRole('link', { name: 'Segment is Traffic from Google' })
    .click()

  await modal(page).getByRole('link', { name: 'Edit segment' }).click()

  await addUtmSourceFilter(page, 'Adwords')

  await segmentMenu(page).click()

  await page.getByRole('link', { name: 'Save as a new segment' }).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Create segment' })
  ).toBeVisible()

  await expect(modal(page).getByLabel('Segment name')).toHaveValue(
    'Copy of Traffic from Google'
  )

  await modal(page).getByLabel('Segment name').fill('Ads from Google')

  await modal(page).getByRole('button', { name: 'Save' }).click()

  await page.getByRole('link', { name: 'Segment is Ads from Google' }).click()

  await expect(modal(page)).toContainText('UTM source is Adwords')
  await expect(modal(page)).toContainText('Source is Google')

  await modal(page).getByRole('button', { name: 'Remove filter' }).click()

  await filterButton(page).click()

  await expect(filterItemButton(page, 'Ads from Google')).toBeVisible()
  await expect(filterItemButton(page, 'Traffic from Google')).toBeVisible()

  await filterItemButton(page, 'Traffic from Google').click()

  await page
    .getByRole('link', { name: 'Segment is Traffic from Google' })
    .click()

  await expect(modal(page)).not.toContainText('UTM source is Adwords')
  await expect(modal(page)).toContainText('Source is Google')
})

test('deleting segment', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await page
    .getByRole('link', { name: 'Segment is Traffic from Google' })
    .click()

  await modal(page).getByRole('link', { name: 'Edit segment' }).click()

  await segmentMenu(page).click()

  await page.getByRole('link', { name: 'Delete segment' }).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Delete personal segment' })
  ).toBeVisible()

  await modal(page).getByRole('button', { name: 'Delete' }).click()

  await filterButton(page).click()

  await expect(filterItemButton(page, 'Traffic from Google')).toBeHidden()
})

test('closing edited segment without saving', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await page
    .getByRole('link', { name: 'Segment is Traffic from Google' })
    .click()

  await modal(page).getByRole('link', { name: 'Edit segment' }).click()

  await addUtmSourceFilter(page, 'Adwords')

  await segmentMenu(page).click()

  await page.getByRole('link', { name: 'Close without saving' }).click()

  await filterButton(page).click()

  await filterItemButton(page, 'Traffic from Google').click()

  await page
    .getByRole('link', { name: 'Segment is Traffic from Google' })
    .click()

  await expect(modal(page)).not.toContainText('UTM source is Adwords')
  await expect(modal(page)).toContainText('Source is Google')
})
