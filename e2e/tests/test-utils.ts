import type { Locator, Page } from '@playwright/test'
import { expect } from '@playwright/test'

export async function expectLiveViewConnected(page: Page) {
  await expect
    .poll(() => page.locator('.phx-connected').count())
    .toBeGreaterThan(0)
}

export function randomID() {
  return Math.random().toString(16).slice(2)
}

export const tabButton = (page: Page | Locator, label: HasTextArg) =>
  page.getByTestId('tab-button').filter({ hasText: label })

export const header = (report: Locator, label: HasTextArg) =>
  report
    .getByTestId('report-header')
    .filter({ hasText: label })
    .getByRole('button')

export const expectHeaders = async (report: Locator, headers: HaveTextArg) =>
  expect(report.getByTestId('report-header')).toHaveText(headers)

export const expectRows = async (report: Locator, labels: HaveTextArg) =>
  expect(report.getByTestId('report-row').getByRole('link')).toHaveText(labels)

export const rowLink = (report: Locator, label: HasTextArg) =>
  report.getByTestId('report-row').filter({ hasText: label }).getByRole('link')

export const expectMetricValues = async (
  report: Locator,
  label: HasTextArg,
  values: HaveTextArg
) =>
  expect(
    report
      .getByTestId('report-row')
      .filter({ hasText: label })
      .getByTestId('metric-value')
  ).toHaveText(values)

export const dropdown = (report: Locator) =>
  report.getByTestId('dropdown-items')

export const searchInput = (report: Locator) =>
  report.getByTestId('search-input')

export const modal = (page: Page) => page.locator('.modal')

export const detailsLink = (report: Locator) =>
  report.getByRole('link', { name: 'View details' })

export const closeModalButton = (page: Page) =>
  page.getByRole('button', { name: 'Close modal' })

export const filterButton = (page: Page) =>
  page.getByRole('button', { name: 'Filter', exact: true })

export const filterItemButton = (page: Page, label: HasTextArg) =>
  page.getByTestId('filtermenu').getByRole('link', { name: label, exact: true })

export const applyFilterButton = (page: Page, { disabled = false } = {}) =>
  page.getByRole('button', {
    name: 'Apply filter',
    disabled
  })

export const filterRow = (page: Page, key: string) =>
  page.getByTestId(`filter-row-${key}`)

export const suggestedItem = (scoped: Locator, url: string) =>
  scoped.getByRole('listitem').filter({ hasText: url })

export const filterOperator = (scoped: Locator) =>
  scoped.getByTestId('filter-operator')

export const filterOperatorOption = (scoped: Locator, option: HasTextArg) =>
  scoped.getByTestId('filter-operator-option').filter({ hasText: option })

type HaveTextArg = string | RegExp | ReadonlyArray<string | RegExp>
type HasTextArg = string | RegExp
