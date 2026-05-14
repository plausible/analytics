import { test, expect, Page } from '@playwright/test'
import {
  setupSite,
  populateStats
  // addGoal,
  // addCustomGoal,
  // addPageviewGoal
} from '../fixtures'
import { tabButton } from '../test-utils'

/*
 * V - Loading featured funnel
 * V - Loading featured funnel when there are no events for a given set of conditions and time range
 * - Rendering entries for:
 *   - pageview
 *   - custom event
 *   - wildcard pathname
 *   - custom goal
 *   - pageview goal
 *   - pageview pattern goal
 *   - long event name and long pathname
 *   - 1k events and up with tooltip/label
 *   - bar with computed ratio below minimum
 * - Rapidly reloading dashboard until rate limit error kicks in
 * - Deselecting all
 * - Selecting different entry at first step with an empty journey
 * - Rapidly selecting different entries until rate limit kicks in
 * - Rapidly deselecting and selecting again the same entry until rate limit kicks in
 * - Deselecting entry at first step with with an empty journey
 * - Searching entries in the first step, with match
 * - Searching entries in the first step, with no match
 * - Selecting different entry with filtering applied
 * - Deselecting and selecting again with filtering applied at first
 * - Selecting entry in the second step
 * - Rapidly selecting different entries in the second step until rate limit kicks in
 * - Rapidly deselecting and selecting again the same entry in second step until rate limit kicks in
 * - Filtering for "no further action" in the second step
 * - Resizing viewport for a 3-step journey
 * - Switching from "Starting point" to "End point" and back
 * - Switching to "End point" and exploring a 3-step journey, switching back
 * - Selecting a different 2nd step in a 3-step journey
 * - Deselecting 2nd step in a 3-step journey
 * - Selecting a different 1st step in a 3-step journey
 * - Deselecting 1st step in a 3-step journey
 * - Changing period with a 3-step journey with results present in all steps
 * - Changing period with a 3-step journey where there are no results for any of the steps
 * - Changing period with a 3-step funnel where there are no results for the 3rd step
 * - Exploring journey hitting the 20-step limit
 */

const getReport = (page: Page) => page.getByTestId('report-behaviours')
const getExplorationTabButton = (report: Locator) =>
  tabButton(report, 'Explore')

test('load featured tunnel with only a single step', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/page',
        timestamp: { hoursAgo: 40 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')

  await expect(firstColumn).toBeVisible()

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/page'])

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['1'])

  await expect(secondColumn).toHaveText(/1 step after/)
  await expect(secondColumn).toHaveText(/No further steps found/)
})

// current version is often stuck loading if the timing is unlucky
test('load featured tunnel and switch to a period with no events without waiting for load', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/page',
        timestamp: { hoursAgo: 40 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  // switch to 'Today'
  await page.keyboard.press('d')

  await expect(report).toHaveText(/No data yet/)
})

test('load featured tunnel and switch to a period with no events', async ({
  page,
  request
}) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/page',
        timestamp: { hoursAgo: 40 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  const firstColumn = report.getByTestId('exploration-column-0')

  await expect(firstColumn).toBeVisible()

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/page'])

  // switch to 'Today'
  await page.keyboard.press('d')

  await expect(report).toHaveText(/No data yet/)
})

test('load a 3-step featured funnel', async ({ page, request }) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/login',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/dashboard',
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 124,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 124,
        name: 'pageview',
        pathname: '/login',
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/another',
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/journey',
        timestamp: { minutesAgo: 35 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')
  const thirdColumn = report.getByTestId('exploration-column-2')

  await expect(firstColumn).toBeVisible()
  await expect(secondColumn).toBeVisible()
  await expect(thirdColumn).toBeVisible()

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/home', '/login', '/another', '/dashboard', '/journey'])

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['3', '2', '1', '1', '1'])

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/login', 'no further action'])

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['2', '1'])

  await expect(
    thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['no further action', '/dashboard'])

  await expect(
    thirdColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['1', '1'])

  await expect(secondColumn).toHaveText(/1 step after/)
  await expect(thirdColumn).toHaveText(/2 steps after/)
})
