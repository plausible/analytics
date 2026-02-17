import { test, expect } from '@playwright/test'
import { setupSite, populateStats } from '../fixtures.ts'

const filterButton = (page) =>
  page.getByRole('button', { name: 'Filter', exact: true })
const applyFilterButton = (page, { disabled = false } = {}) =>
  page.getByRole('button', {
    name: 'Apply filter',
    disabled
  })
const filterRow = (page, key) => page.getByTestId(`filter-row-${key}`)
const suggestedItem = (scoped, url) =>
  scoped.getByRole('listitem').filter({ hasText: url })
const filterOperator = (scoped) => scoped.getByTestId('filter-operator')
const filterOperatorOption = (scoped, option) =>
  scoped.getByTestId('filter-operator-option').filter({ hasText: option })

test.describe('page filtering tests', () => {
  const pageFilterButton = (page) =>
    page.getByTestId('filtermenu').getByRole('link', { name: 'Page' })

  test('filtering by page with detailed behavior test', async ({
    page,
    request
  }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', pathname: '/page1' },
        { name: 'pageview', pathname: '/page2' },
        { name: 'pageview', pathname: '/page3' },
        { name: 'pageview', pathname: '/other' }
      ]
    })

    await page.goto('/' + domain)

    const pageFilterRow = filterRow(page, 'page')
    const pageInput = page.getByPlaceholder('Select a Page')

    await filterButton(page).click()
    await pageFilterButton(page).click()

    await expect(
      page.getByRole('heading', { name: 'Filter by Page' })
    ).toBeVisible()

    await expect(applyFilterButton(page, { disabled: true })).toBeVisible()
    await pageInput.fill('page')

    await expect(suggestedItem(pageFilterRow, '/page1')).toBeVisible()
    await expect(suggestedItem(pageFilterRow, '/page2')).toBeVisible()
    await expect(suggestedItem(pageFilterRow, '/page3')).toBeVisible()
    await expect(applyFilterButton(page, { disabled: true })).toBeVisible()

    await pageInput.fill('/page1')

    await expect(suggestedItem(pageFilterRow, '/page1')).toBeVisible()
    await expect(applyFilterButton(page, { disabled: true })).toBeVisible()

    await suggestedItem(pageFilterRow, '/page1').click()
    await expect(applyFilterButton(page)).toBeVisible()

    await applyFilterButton(page).click()

    await expect(page).toHaveURL(/f=is,page,\/page1/)

    await expect(
      page.getByRole('link', { name: 'Page is /page1' })
    ).toHaveAttribute('title', 'Edit filter: Page is /page1')
  })

  test('filtering by page using different operators', async ({
    page,
    request
  }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { name: 'pageview', pathname: '/page1' },
        { name: 'pageview', pathname: '/page2' },
        { name: 'pageview', pathname: '/page3' },
        { name: 'pageview', pathname: '/other' }
      ]
    })

    await page.goto('/' + domain)

    const pageFilterRow = filterRow(page, 'page')
    const pageInput = page.getByPlaceholder('Select a Page')

    await test.step("'is not' operator", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await filterOperator(pageFilterRow).click()
      await filterOperatorOption(pageFilterRow, 'is not').click()
      await pageInput.fill('page')
      await suggestedItem(pageFilterRow, '/page1').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page is not /page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is_not,page,\/page1/)

      await page
        .getByRole('button', { name: 'Remove filter: Page is not /page1' })
        .click()

      await expect(page).not.toHaveURL(/f=is_not,page,\/page1/)
    })

    await test.step("'contains' operator", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await filterOperator(pageFilterRow).click()
      await filterOperatorOption(pageFilterRow, 'contains').click()
      await pageInput.fill('page1')
      await suggestedItem(pageFilterRow, "Filter by 'page1'").click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page contains page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=contains,page,page1/)

      await page
        .getByRole('button', { name: 'Remove filter: Page contains page1' })
        .click()

      await expect(page).not.toHaveURL(/f=contains,page,page1/)
    })

    await test.step("'does not contain' operator", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await filterOperator(pageFilterRow).click()
      await filterOperatorOption(pageFilterRow, 'does not contain').click()
      await pageInput.fill('page1')
      await suggestedItem(pageFilterRow, "Filter by 'page1'").click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page does not contain page1' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=contains_not,page,page1/)

      await page
        .getByRole('button', {
          name: 'Remove filter: Page does not contain page1'
        })
        .click()

      await expect(page).not.toHaveURL(/f=contains_not,page,page1/)
    })

    await test.step("'is' operator with multiple choices", async () => {
      await filterButton(page).click()
      await pageFilterButton(page).click()

      await pageInput.fill('page')
      await suggestedItem(pageFilterRow, '/page2').click()
      await pageInput.fill('page')
      await suggestedItem(pageFilterRow, '/page3').click()

      await applyFilterButton(page).click()

      await expect(
        page.getByRole('link', { name: 'Page is /page2 or /page3' })
      ).toBeVisible()

      await expect(page).toHaveURL(/f=is,page,\/page2,\/page3/)
    })
  })

  test('filtering by entry page', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { user_id: 123, name: 'pageview', pathname: '/page1' },
        { user_id: 123, name: 'pageview', pathname: '/page2' },
        { user_id: 123, name: 'pageview', pathname: '/page3' },
        { user_id: 124, name: 'pageview', pathname: '/page1' },
        { user_id: 124, name: 'pageview', pathname: '/page2' },
        { name: 'pageview', pathname: '/page1' },
        { name: 'pageview', pathname: '/other' }
      ]
    })

    await page.goto('/' + domain)

    const entryPageFilterRow = filterRow(page, 'entry_page')
    const entryPageInput = page.getByPlaceholder('Select an Entry Page')

    await filterButton(page).click()
    await pageFilterButton(page).click()

    await entryPageInput.fill('page')
    await suggestedItem(entryPageFilterRow, '/page1').click()

    await applyFilterButton(page).click()

    await expect(
      page.getByRole('link', { name: 'Entry page is /page1' })
    ).toBeVisible()

    await expect(page).toHaveURL(/f=is,entry_page,\/page1/)
  })

  test('filtering by exit page', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { user_id: 123, name: 'pageview', pathname: '/page1' },
        { user_id: 123, name: 'pageview', pathname: '/page2' },
        { user_id: 123, name: 'pageview', pathname: '/page3' },
        { user_id: 124, name: 'pageview', pathname: '/page1' },
        { user_id: 124, name: 'pageview', pathname: '/page2' },
        { name: 'pageview', pathname: '/page1' },
        { name: 'pageview', pathname: '/other' }
      ]
    })

    await page.goto('/' + domain)

    const exitPageFilterRow = filterRow(page, 'exit_page')
    const exitPageInput = page.getByPlaceholder('Select an Exit Page')

    await filterButton(page).click()
    await pageFilterButton(page).click()

    await exitPageInput.fill('page')
    await suggestedItem(exitPageFilterRow, '/page3').click()

    await applyFilterButton(page).click()

    await expect(
      page.getByRole('link', { name: 'Exit page is /page3' })
    ).toBeVisible()

    await expect(page).toHaveURL(/f=is,exit_page,\/page3/)
  })
})
