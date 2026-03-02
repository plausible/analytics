import { test, expect } from '@playwright/test'
import { setupSite, populateStats } from '../fixtures.ts'
import {
  filterButton,
  filterItemButton,
  applyFilterButton,
  filterRow,
  suggestedItem,
  modal
} from '../test-utils.ts'

const sourceFilterButton = (page) => filterItemButton(page, 'Source')
const utmTagsFilterButton = (page) => filterItemButton(page, 'UTM tags')

const addSourceFilter = async (page, sourceLabel) => {
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

const addUtmSourceFilter = async (page, utmSource) => {
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

const createPersonalSegment = async (page, name) => {
  await page.getByRole('button', { name: 'See actions' }).click()

  await page.getByRole('link', { name: 'Save as segment' }).click()

  await modal(page).getByLabel('Segment name').fill(name)

  await modal(page).getByRole('button', { name: 'Save' }).click()

  await expect(page).toHaveURL(/f=is,segment,[0-9]+/)
}

test('saving a segment', async ({ page, request }) => {
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

  await addSourceFilter(page, 'Google')
  await createPersonalSegment(page, 'Traffic from Google')
  await addUtmSourceFilter(page, 'Adwords')

  await expect(
    page.getByRole('link', { name: 'UTM source is Adwords' })
  ).toBeVisible()

  await page
    .getByRole('button', { name: 'See 1 more filter and actions' })
    .click()

  await expect(
    page.getByRole('link', { name: 'Segment is Traffic from Google' })
  ).toBeVisible()

  await expect(page).toHaveURL(/f=is,segment,[0-9]+/)
  await expect(page).toHaveURL(/f=is,utm_source,Adwords/)

  await expect(
    modal(page).getByRole('heading', { name: 'Create segment' })
  ).toBeHidden()
})
