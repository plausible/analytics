// Module to wrap playwright.

import { test as playwrightTest, expect, Page, Locator, TestInfo } from '@playwright/test'

export { expect, Page, Locator, TestInfo } from '@playwright/test'

// Test wrapper which fails if any JS errors are logged.
//
// This is a catch-all error handling tool - all errors which
// are not handled in JS trigger errors, such as 500s or other
// frontend bugs.
//
// Idea from https://www.checklyhq.com/blog/track-frontend-javascript-exceptions-with-playwright/
export const test = playwrightTest.extend<{ page: void }>({
  page: async ({ page }: { page: any }, use: any) => {
    // Track errors
    const errors: Array<Error> = []
    page.addListener("pageerror", (error: any) => {
      errors.push(error)
    })

    // Run the test
    await use(page)

    // Check no errors
    expect(errors).toHaveLength(0)
  },
})

const snapshotsIndexes: Record<string, number> = {}

export async function screenshot(locator: Page | Locator, testInfo: TestInfo): Promise<void> {
  const root = testInfo.snapshotPath()
  const snapshotIndex = (snapshotsIndexes[root] || 0) + 1
  snapshotsIndexes[root] = snapshotIndex

  const path = testInfo.snapshotPath(`${snapshotIndex}.png`)

  await locator.screenshot({ path })
}

test.beforeEach(async ({ context }) => {
  await context.route(/changes.txt/, route => route.fulfill({ status: 200, body: '2020-01-01' }))
})
