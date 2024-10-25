import { test, expect, Page } from './playwright'

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

// test('adding filters')

test('can open all modals', async ({ page }) => {
  await checkBreakdownModal(page, 'section::sources')
  await checkBreakdownModal(page, 'section::pages')
  await checkBreakdownModal(page, 'section::locations')
  await checkBreakdownModal(page, 'section::devices')
  await checkBreakdownModal(page, 'section::behaviors')
})

test('with revenue goal filter applied sees revenue metrics in top stats', async ({ page }) => {
  await expect(page.getByTestId("section::top-stats")).not.toHaveText(/Total revenue/)
  await expect(page.getByTestId("section::top-stats")).not.toHaveText(/Average revenue/)

  await page.getByText("North America Purchases").click()
  await waitForData(page)

  await expect(page.getByTestId("section::top-stats")).toHaveText(/Total revenue/)
  await expect(page.getByTestId("section::top-stats")).toHaveText(/Average revenue/)
})

// test('dashboard comparison with previous period')
// test('realtime dashboard')


async function waitForData(page: Page) {
  const loading = page.locator(".loading")

  await page.waitForSelector("#main-graph-canvas")
  await loading.waitFor({ state: "visible", timeout: 50 }).catch(() => {})
  await expect(loading).toHaveCount(0)
}

async function checkBreakdownModal(page: Page, listTestId: string) {
  await page.getByTestId(listTestId).getByTestId('details-link').click()
  await waitForData(page)

  await page.getByRole('button', { name: '✕' }).click()
}
