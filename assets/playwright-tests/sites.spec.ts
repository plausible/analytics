import { test, expect } from './playwright'

test('site card', async ({ page }) => {
  await page.goto('/sites')

  const siteCard = page.locator("li[data-domain='dummy.site']")

  await expect(siteCard).toHaveText(/\d+\s+visitors in last 24h/)
  await siteCard.click()

  await page.waitForURL("/dummy.site")

  await expect(page.locator("body")).toHaveText(/\d+\s+current visitors/)
})
