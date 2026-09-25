import { test, expect, APIRequestContext, Page } from '@playwright/test'
import { setupSite, populateStats } from '../fixtures'
import {
  filterButton,
  filterSubmenuSegmentItem,
  openFilterSubmenuItem,
  openSegmentsSubmenu,
  closeFilterMenu,
  filterSubmenuButton,
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

const openSegmentPillMenu = async (page: Page, segmentName: string) => {
  await page
    .getByRole('button', { name: `Segment is ${segmentName}`, exact: true })
    .click()
}

const saveEditedSegmentButton = (page: Page) =>
  page.getByRole('button', { name: 'Save', exact: true })

const enterEditMode = async (page: Page, segmentName: string) => {
  await openSegmentPillMenu(page, segmentName)
  await page.getByRole('link', { name: 'Edit segment' }).click()
  await expect(saveEditedSegmentButton(page)).toBeVisible()
}

const segmentItemButton = (page: Page, name: string) =>
  filterSubmenuSegmentItem(page, name)

const addSourceFilter = async (page: Page, sourceLabel: string) => {
  const sourceFilterRow = filterRow(page, 'source')
  const sourceInput = page.getByPlaceholder('Select a Source')

  await filterButton(page).click()
  await openFilterSubmenuItem(page, 'Source', 'Source')

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
  await openFilterSubmenuItem(page, 'UTM tags', 'UTM source')

  await utmSourceInput.click()
  await suggestedItem(utmSourceFilterRow, utmSource).click()

  await applyFilterButton(page).click()

  const url = new RegExp(`f=is,utm_source,${utmSource}`)
  await expect(page).toHaveURL(url)
}

const createPersonalSegment = async (page: Page, name: string) => {
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

    await page.getByRole('link', { name: 'Save as segment' }).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Create segment' })
    ).toBeVisible()

    await expect(modal(page).getByLabel('Segment name')).toHaveValue(
      'Source is Facebook'
    )

    await expect(
      modal(page).getByRole('radio', { name: 'Personal segment' })
    ).toBeChecked()

    await modal(page).getByRole('button', { name: 'Save' }).click()

    await expect(page).toHaveURL(/f=is,segment,[0-9]+/)

    await expect(
      page.getByRole('button', {
        name: 'Remove filter: Segment is Source is Facebook'
      })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Segment is Source is Facebook'
      })
      .click()

    await filterButton(page).click()
    await openSegmentsSubmenu(page)

    await expect(segmentItemButton(page, 'Source is Facebook')).toBeVisible()

    await closeFilterMenu(page)
  })

  await test.step('creating a personal segment with a custom name', async () => {
    await addSourceFilter(page, 'Google')

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
      page.getByRole('button', {
        name: 'Remove filter: Segment is Traffic from Google'
      })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Segment is Traffic from Google'
      })
      .click()

    await filterButton(page).click()
    await openSegmentsSubmenu(page)

    await expect(segmentItemButton(page, 'Traffic from Google')).toBeVisible()
    await expect(segmentItemButton(page, 'Source is Facebook')).toBeVisible()

    await closeFilterMenu(page)
  })

  await test.step('creating a site segment from more than one filter', async () => {
    await addSourceFilter(page, 'Google')
    await addUtmSourceFilter(page, 'Adwords')

    await page.getByRole('link', { name: 'Save as segment' }).click()

    await expect(
      modal(page).getByRole('heading', { name: 'Create segment' })
    ).toBeVisible()

    await expect(modal(page).getByLabel('Segment name')).toHaveValue(
      'UTM source is Adwords and Source is Google'
    )

    await modal(page).getByLabel('Segment name').fill('Ads from Google')

    const siteSegmentRadio = modal(page).getByRole('radio', {
      name: 'Site segment'
    })

    await siteSegmentRadio.click()

    await expect(siteSegmentRadio).toBeChecked()

    await modal(page).getByRole('button', { name: 'Save' }).click()

    await expect(page).toHaveURL(/f=is,segment,[0-9]+/)

    await expect(
      page.getByRole('button', {
        name: 'Remove filter: Segment is Ads from Google'
      })
    ).toBeVisible()

    await page
      .getByRole('button', {
        name: 'Remove filter: Segment is Ads from Google'
      })
      .click()

    await filterButton(page).click()
    await openSegmentsSubmenu(page)

    await expect(segmentItemButton(page, 'Ads from Google')).toBeVisible()
    await expect(segmentItemButton(page, 'Traffic from Google')).toBeVisible()
    await expect(segmentItemButton(page, 'Source is Facebook')).toBeVisible()

    await closeFilterMenu(page)
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

  await expect(
    page.getByRole('link', { name: 'UTM source is Adwords' })
  ).toBeVisible()
  await expect(
    page.getByRole('button', {
      name: 'Remove filter: Segment is Traffic from Google'
    })
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

  await enterEditMode(page, 'Traffic from Google')

  await addUtmSourceFilter(page, 'Adwords')

  await saveEditedSegmentButton(page).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Update segment' })
  ).toBeVisible()

  await expect(modal(page).getByLabel('Segment name')).toHaveValue(
    'Traffic from Google'
  )

  await modal(page).getByLabel('Segment name').fill('Ads from Google')

  await modal(page).getByRole('button', { name: 'Save' }).click()

  await expect(
    page.getByRole('button', {
      name: 'Remove filter: Segment is Ads from Google'
    })
  ).toBeVisible()

  await enterEditMode(page, 'Ads from Google')

  await expect(
    page.getByRole('link', { name: 'UTM source is Adwords' })
  ).toBeVisible()
  await expect(
    page.getByRole('link', { name: 'Source is Google' })
  ).toBeVisible()

  await page.getByRole('link', { name: 'Cancel' }).click()

  await page
    .getByRole('button', {
      name: 'Remove filter: Segment is Ads from Google'
    })
    .click()

  await expect(page).not.toHaveURL(/f=is,segment,[0-9]+/)

  await filterButton(page).click()
  await openSegmentsSubmenu(page)

  await expect(segmentItemButton(page, 'Ads from Google')).toBeVisible()
  await expect(segmentItemButton(page, 'Traffic from Google')).toBeHidden()
})

test('duplicating a segment', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await openSegmentPillMenu(page, 'Traffic from Google')

  await page.getByRole('button', { name: 'Duplicate segment' }).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Create segment' })
  ).toBeVisible()

  await expect(modal(page).getByLabel('Segment name')).toHaveValue(
    'Copy of Traffic from Google'
  )

  await modal(page).getByLabel('Segment name').fill('Google copy')

  await modal(page).getByRole('button', { name: 'Save' }).click()

  await enterEditMode(page, 'Google copy')

  await expect(
    page.getByRole('link', { name: 'Source is Google' })
  ).toBeVisible()

  await page.getByRole('link', { name: 'Cancel' }).click()

  await page
    .getByRole('button', {
      name: 'Remove filter: Segment is Google copy'
    })
    .click()

  await filterButton(page).click()
  await openSegmentsSubmenu(page)

  await expect(segmentItemButton(page, 'Google copy')).toBeVisible()
  await expect(segmentItemButton(page, 'Traffic from Google')).toBeVisible()
})

test('deleting segment', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await openSegmentPillMenu(page, 'Traffic from Google')

  await page.getByRole('button', { name: 'Delete segment' }).click()

  await expect(
    modal(page).getByRole('heading', { name: 'Delete personal segment' })
  ).toBeVisible()

  await modal(page).getByRole('button', { name: 'Delete' }).click()

  await filterButton(page).click()

  // The only segment is gone, so the filter menu no longer offers segments at all.
  await expect(filterSubmenuButton(page, 'Segment')).toBeHidden()
})

test('cancelling edited segment without saving', async ({ page, request }) => {
  const { domain } = await setupSiteAndStats({ page, request })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')

  await enterEditMode(page, 'Traffic from Google')

  await addUtmSourceFilter(page, 'Adwords')

  await page.getByRole('link', { name: 'Cancel' }).click()

  await expect(page).toHaveURL(/f=is,segment,[0-9]+/)
  await expect(page).not.toHaveURL(/f=is,utm_source,Adwords/)

  await enterEditMode(page, 'Traffic from Google')

  await expect(
    page.getByRole('link', { name: 'UTM source is Adwords' })
  ).toBeHidden()
  await expect(
    page.getByRole('link', { name: 'Source is Google' })
  ).toBeVisible()
})
