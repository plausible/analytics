import { test, expect } from './playwright'

test('can navigate the dashboard via keyboard shortcuts', async ({ page }) => {
  await page.goto('dummy.site')
  await page.waitForSelector("#main-graph-canvas")

  const dateMenuButton = page.getByTestId('date-menu-button')

  async function testShortcut(key: string, pattern: string | RegExp) {
    page.keyboard.down(key)
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
