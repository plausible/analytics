import type { Locator, Page } from '@playwright/test'
import { expect } from '@playwright/test'
import {
  ZonedDateTime,
  ZoneOffset,
  ChronoUnit,
  DateTimeFormatter
} from '@js-joda/core'

export function currentTime(): ZonedDateTime {
  return ZonedDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS)
}

export function timeToISO(ts: ZonedDateTime): string {
  return ts.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
}

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

export const tabButtonWithDropdown = (
  page: Page | Locator,
  label: HasTextArg
) => page.getByTestId('tab-button-with-dropdown').filter({ hasText: label })

export const header = (report: Locator, label: HasTextArg) =>
  report
    .getByTestId('report-header')
    .filter({ hasText: label })
    .getByRole('button')

export const expectHeaders = async (report: Locator, headers: HaveTextArg) =>
  expect(report.getByTestId('report-header')).toHaveText(headers)

export const expectRows = async (report: Locator, labels: HaveTextArg) =>
  expect(
    report.getByTestId('report-row').getByTestId('dimension-value')
  ).toHaveText(labels)

export const rowLink = (report: Locator, label: HasTextArg) =>
  report
    .getByTestId('report-row')
    .filter({ hasText: label })
    .getByTestId('dimension-value')

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

// Needed before opening dropdown again right after it closes (usually, when picking an item).
// There's a leave transition for the dropdown and interacting with the dropdown opener
// during the transition may mean that the dropdown doesn't actually open.
export const expectDropdownClosed = async (report: Locator) =>
  expect(dropdown(report)).toHaveCount(0)

export const searchInput = (report: Locator) =>
  report.getByTestId('search-input')

export const modal = (page: Page) => page.locator('.modal')

export const detailsLink = (report: Locator) =>
  report.getByRole('link', { name: 'View details' })

export const closeModalButton = (page: Page) =>
  page.getByRole('button', { name: 'Close modal' })

export const filterButton = (page: Page) =>
  page.getByRole('button', { name: /^(Filter|Add filter)$/ })

const filterMenu = (page: Page) => page.getByTestId('filtermenu')

const filterSubmenu = (page: Page) => page.getByTestId('filtermenu-submenu')

export const filterItemButton = (page: Page, label: HasTextArg) =>
  filterMenu(page).getByRole('button', { name: label, exact: true })

export const filterSubmenuItemButton = (page: Page, label: HasTextArg) =>
  filterSubmenu(page).getByRole('button', { name: label, exact: true })

export const filterSubmenuSegmentItem = (page: Page, name: HasTextArg) =>
  filterSubmenu(page).getByRole('link').filter({ hasText: name })

export const openFilterSubmenuItem = async (
  page: Page,
  row: string,
  item: string
) => {
  await filterItemButton(page, row).click()
  await filterSubmenuItemButton(page, item).click()
}

export const openSegmentsSubmenu = (page: Page) =>
  filterItemButton(page, 'Segment').click()

// Waits for the panel to unmount. Reopening the menu during its closing
// animation leaves the panel unmounted.
export const closeFilterMenu = async (page: Page) => {
  await filterButton(page).click()
  await expect(filterMenu(page)).toBeHidden()
}

export const openPropertyKeys = (page: Page) =>
  filterItemButton(page, 'Property').click()

export const propertyKeySearch = (page: Page) =>
  page.getByRole('combobox', { name: 'Properties' })

export const propertyKeyOption = (page: Page, key: string) =>
  page
    .getByRole('listbox', { name: 'Properties' })
    .getByRole('option', { name: key, exact: true })

export const filterPill = (page: Page, name: string) =>
  page.getByRole('group', { name, exact: true })

export const filterPillValuesButton = (page: Page, name: string) =>
  page.getByRole('button', { name: `Edit filter: ${name}`, exact: true })

export const filterPillOperatorButton = (page: Page, name: string) =>
  page.getByRole('button', { name: `Change operator: ${name}`, exact: true })

export const filterOperatorOption = (page: Page, option: string) =>
  page
    .getByRole('group', { name: 'Operators' })
    .getByRole('button', { name: option, exact: true })

export const filterValueSearch = (page: Page) =>
  page.getByRole('combobox', { name: /^Values/ })

export const filterValueOption = (page: Page, label: string) =>
  page
    .getByRole('listbox', { name: /^Values/ })
    .getByRole('option', { name: label, exact: true })

export const pickFilterValue = async (
  page: Page,
  { search, value }: { search?: string; value: string }
) => {
  if (search !== undefined) {
    await filterValueSearch(page).fill(search)
  }
  await filterValueOption(page, value).click()
}

export const closeFilterEditor = async (page: Page) => {
  await page.keyboard.press('Escape')
  await expect(page.getByRole('listbox', { name: /^Values/ })).toBeHidden()
}

type HaveTextArg = string | RegExp | ReadonlyArray<string | RegExp>
type HasTextArg = string | RegExp
