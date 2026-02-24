import type { Page } from '@playwright/test'
import { expect } from '@playwright/test'

export async function expectLiveViewConnected(page: Page) {
  return expect(page.locator('.phx-connected')).toHaveCount(1)
}

export function randomID() {
  return Math.random().toString(16).slice(2)
}

export const tabButton = (page, label) =>
  page.getByTestId('tab-button').filter({ hasText: label })

export const expectHeaders = async (report, headers) =>
  expect(report.getByTestId('report-header')).toHaveText(headers)

export const expectRows = async (report, labels) =>
  expect(report.getByTestId('report-row').getByRole('link')).toHaveText(labels)

export const rowLink = (report, label) =>
  report.getByTestId('report-row').filter({ hasText: label }).getByRole('link')

export const expectMetricValues = async (report, label, values) =>
  expect(
    report
      .getByTestId('report-row')
      .filter({ hasText: label })
      .getByTestId('metric-value')
  ).toHaveText(values)

export const dropdown = (report) => report.getByTestId('dropdown-items')


