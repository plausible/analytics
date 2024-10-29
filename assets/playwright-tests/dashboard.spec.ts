import { test, expect, Page } from './playwright'

const MODALS = [
  { key: 'UTM Medium', sectionSelector: 'section::sources' },
  { key: 'UTM Source', sectionSelector: 'section::sources' },
  { key: 'UTM Campaign', sectionSelector: 'section::sources' },
  { key: 'Top Pages', sectionSelector: 'section::pages' },
  { key: 'Entry Pages', sectionSelector: 'section::pages' },
  { key: 'Exit Pages', sectionSelector: 'section::pages' },
  { key: 'Map', sectionSelector: 'section::locations' },
  { key: 'Countries', sectionSelector: 'section::locations' },
  { key: 'Regions', sectionSelector: 'section::locations' },
  { key: 'Cities', sectionSelector: 'section::locations' },
  { key: 'Browser', sectionSelector: 'section::devices' },
  { key: 'OS', sectionSelector: 'section::devices' },
  { key: 'Size', sectionSelector: 'section::devices' },
  { key: 'Goals', sectionSelector: 'section::behaviors' },
  { key: 'Properties', sectionSelector: 'section::behaviors' },
]

test.beforeEach(async ({page}) => {
  await page.goto('/dummy.site')
  await waitForData(page)
})

test('can navigate the dashboard via keyboard shortcuts', async ({ page }) => {
  const dateMenuButton = page.getByTestId('date-menu-button')

  async function testShortcut(key: string, pattern: string | RegExp) {
    page.keyboard.down(key)
    await waitForData(page)
    await expect(dateMenuButton).toHaveText(pattern)
    await expect(page).toHaveScreenshot()
  }

  await testShortcut("D", "Today")
  await testShortcut("E", /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)/)
  await testShortcut("R", "Realtime")
  await testShortcut("W", "Last 7 days")
  await testShortcut("T", "Last 30 days")
  await testShortcut("M", "Month to Date")
  await testShortcut("Y", "Year to Date")
  await testShortcut("L", "Last 12 months")
  await testShortcut("A", "All time")
})

MODALS.forEach(({ key, sectionSelector }) => {
  test(`can open ${key} modal`, async ({ page }) => {
    await clickOpenBreakdownModal(page, sectionSelector, key)

    await checkBreakdownModal(page, sectionSelector)
  })

  test(`can open ${key} modal in comparison mode`, async ({ page }) => {
    page.keyboard.down("X")
    await waitForData(page)

    await clickOpenBreakdownModal(page, sectionSelector, key)
    await checkBreakdownModal(page, sectionSelector)
  })
})

test('with revenue goal filter applied sees revenue metrics in top stats', async ({ page }) => {
  await expect(page.getByTestId("section::top-stats")).not.toHaveText(/Total revenue/)
  await expect(page.getByTestId("section::top-stats")).not.toHaveText(/Average revenue/)

  await page.getByText("North America Purchases").click()
  await waitForData(page)

  await expect(page.getByTestId("section::top-stats")).toHaveText(/Total revenue/)
  await expect(page.getByTestId("section::top-stats")).toHaveText(/Average revenue/)

  await expect(page.getByTestId("section::top-stats")).toHaveScreenshot()
})

test('dashboard comparison with previous period', async ({ page }) => {
  await page.getByTestId('date-menu-button').click()
  await page.getByTestId('datemenu').getByRole('link', { name: /Compare/ }).click()
  await waitForData(page)

  await expect(page).toHaveScreenshot()
})

async function waitForData(page: Page) {
  const loading = page.locator(".loading")

  await page.waitForSelector("#main-graph-canvas")
  await loading.waitFor({ state: "visible", timeout: 50 }).catch(() => {})
  await expect(loading).toHaveCount(0)
}

async function clickOpenBreakdownModal(page: Page, sectionSelector: string, key: string) {
  if (sectionSelector === 'section::sources') {
    await page.getByTestId("campaign-menu").click()
    await page.getByRole('menuitem', { name: key }).click()
  } else {
    await page.getByRole('button', { name: key }).click()
  }
}

async function checkBreakdownModal(page: Page, listTestId: string) {
  await page.getByTestId(listTestId).getByTestId('details-link').click()
  await waitForData(page)
  await expect(page.locator(".modal__container")).toHaveScreenshot()

  await page.getByRole('button', { name: '✕' }).click()
}
