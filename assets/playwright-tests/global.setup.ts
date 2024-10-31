import { test as setup, expect } from './playwright'
import path from 'path'

const authFile = path.join(__dirname, '../playwright-tests/.auth/user.json')

setup('login', async ({ page }) => {
  await page.goto('/login')

  await page.getByLabel('Email').fill("user@plausible.test")
  await page.getByLabel("Password").fill("plausible")

  await page.getByRole('button', { name: 'Log in' }).click()

  await page.waitForURL("/sites")
  await expect(page.locator("body")).toHaveText(/My Sites/)
  await expect(page.locator("body")).toHaveText(/dummy.site/)

  await page.context().storageState({ path: authFile })
})
