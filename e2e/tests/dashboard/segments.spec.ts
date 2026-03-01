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

test('saving personal segment', async ({ page, request }) => {
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

  const sourceFilterRow = filterRow(page, 'source')
  const sourceInput = page.getByPlaceholder('Select a Source')

  await filterButton(page).click()
  await sourceFilterButton(page).click()

  await sourceInput.click()
  await suggestedItem(sourceFilterRow, 'Facebook').click()

  await applyFilterButton(page).click()

  await expect(page).toHaveURL(/f=is,source,Facebook/)

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
})
