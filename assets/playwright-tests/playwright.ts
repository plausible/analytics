// Module to wrap playwright.

import { test as playwrightTest, expect } from '@playwright/test'

export { expect, Page } from '@playwright/test'

// Test wrapper which fails if any JS errors are logged.
//
// This is a catch-all error handling tool - all errors which
// are not handled in JS trigger errors, such as 500s or other
// frontend bugs.
//
// Idea from https://www.checklyhq.com/blog/track-frontend-javascript-exceptions-with-playwright/
export const test = playwrightTest.extend<{ page: void }>({
  page: async ({ page }: { page: any }, use: any) => {
    const errors: Array<Error> = []

    page.addListener("pageerror", (error: any) => {
      errors.push(error)
    })

    // run the test
    await use(page)

    expect(errors).toHaveLength(0)
  },
})
