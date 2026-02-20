import { test, expect } from '@playwright/test'
import { ZonedDateTime, ZoneOffset, ChronoUnit } from '@js-joda/core'
import { setupSite, populateStats } from '../fixtures.ts'

test('top stats show relevant metrics', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/',
        timestamp: { minutesAgo: 120 }
      },
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/',
        timestamp: { minutesAgo: 60 }
      },
      {
        user_id: 123,
        name: 'pageview',
        pathname: '/page1',
        timestamp: { minutesAgo: 50 }
      },
      {
        user_id: 456,
        name: 'pageview',
        pathname: '/',
        timestamp: { minutesAgo: 80 }
      }
    ]
  })

  await page.goto('/' + domain)

  await expect(page).toHaveTitle(/Plausible/)

  await expect(page.getByRole('button', { name: domain })).toBeVisible()

  await expect(page.locator('#visitors')).toHaveText('2')
  await expect(page.locator('#visits')).toHaveText('3')
  await expect(page.locator('#pageviews')).toHaveText('4')
  await expect(page.locator('#views_per_visit')).toHaveText('1.33')
  await expect(page.locator('#bounce_rate')).toHaveText('67%')
  await expect(page.locator('#visit_duration')).toHaveText('3m 20s')
})

test('different time ranges are supported', async ({ page, request }) => {
  const now = ZonedDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS)
  const startOfDay = now.truncatedTo(ChronoUnit.DAYS)
  const startOfYesterday = startOfDay.minusDays(1)
  const startOfMonth = startOfDay.withDayOfMonth(1)
  const startOfLastMonth = startOfMonth.minusMonths(1)
  const startOfYear = now.withDayOfYear(1)

  const expectedCounts = [
    { from: startOfDay, to: now, key: 'd', value: 0 },
    { from: startOfYesterday, to: startOfDay, key: 'e', value: 0 },
    { from: now.minusMinutes(30), to: now, key: 'r', value: 0 },
    { from: now.minusHours(24), to: now, key: 'h', value: 0 },
    { from: startOfDay.minusDays(7), to: startOfDay, key: 'w', value: 0 },
    { from: startOfDay.minusDays(28), to: startOfDay, key: 'f', value: 0 },
    { from: startOfDay.minusDays(91), to: startOfDay, key: 'n', value: 0 },
    { from: startOfMonth, to: now, key: 'm', value: 0 },
    { from: startOfLastMonth, to: startOfMonth, key: 'p', value: 0 },
    { from: startOfYear, to: now, key: 'y', value: 0 },
    { from: startOfMonth.minusMonths(12), to: startOfMonth, key: 'l', value: 0 }
  ]

  const eventTimes = [
    now.minusMinutes(20),
    now.minusHours(12),
    now.minusHours(26),
    now.minusHours(30),
    now.minusHours(35),
    now.minusDays(5),
    now.minusDays(17),
    now.minusDays(54),
    now.minusDays(120),
    now.minusDays(720)
  ]

  const events = []

  eventTimes.forEach((ts, idx) => {
    expectedCounts.forEach((expected) => {
      if (ts.compareTo(expected.from) >= 0 && ts.compareTo(expected.to) < 0) {
        expected.value += 1
      }
    })

    events.push({
      user_id: idx + 1,
      name: 'pageview',
      timestamp: ts.toString()
    })
  })

  const { domain } = await setupSite({ page, request })

  await populateStats({ request, domain, events })

  await page.goto('/' + domain)
  await expect(page.getByRole('button', { name: domain })).toBeVisible()

  await expect(page.getByTestId('current-query-period')).toHaveText(
    'Last 28 days'
  )

  const visitors = page.locator('#visitors')

  for (const expected of expectedCounts) {
    await page.keyboard.press(expected.key)
    await expect(visitors).toHaveText(`${expected.value}`)
  }

  // Realtime
  await page.keyboard.press('r')
  await expect(visitors).toHaveText('1')

  // All time
  await page.keyboard.press('a')
  await expect(visitors).toHaveText(`${events.length}`)
})

test('different graph time intervals are available', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', timestamp: { minutesAgo: 60 } },
      { name: 'pageview', timestamp: { daysAgo: 5 } }
    ]
  })

  await page.goto('/' + domain)

  await expect(page.getByTestId('current-query-period')).toHaveText(
    'Last 28 days'
  )

  const intervalButton = page.getByTestId('current-graph-interval')
  const intervalOptions = page.getByTestId('graph-interval')
  await expect(intervalButton).toHaveText('Days')
  await intervalButton.click()
  const intervalOptions28Days = await intervalOptions.allTextContents()

  expect(intervalOptions28Days.indexOf('Days') > -1).toBeTruthy()
  expect(intervalOptions28Days.indexOf('Weeks') > -1).toBeTruthy()

  await page.getByTestId('current-query-period').click()
  await page
    .getByTestId('query-period-picker')
    .getByRole('link', { name: 'Today' })
    .click()

  await expect(intervalButton).toHaveText('Hours')
  await intervalButton.click()
  // The popover does not appear right away
  await expect(intervalOptions).toHaveCount(2)
  const intervalOptionsToday = await intervalOptions.allTextContents()

  expect(intervalOptionsToday.indexOf('Hours') > -1).toBeTruthy()
  expect(intervalOptionsToday.indexOf('Minutes') > -1).toBeTruthy()
})

test('comparing stats over time is supported', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', timestamp: { daysAgo: 2 } },
      { name: 'pageview', timestamp: { daysAgo: 4 } },
      { name: 'pageview', timestamp: { daysAgo: 30 } },
      { name: 'pageview', timestamp: { daysAgo: 30 } },
      { name: 'pageview', timestamp: { daysAgo: 31 } },
      { name: 'pageview', timestamp: { daysAgo: 370 } }
    ]
  })

  await page.goto('/' + domain)

  await expect(page.getByTestId('current-query-period')).toHaveText(
    'Last 28 days'
  )

  await page.getByTestId('query-period-picker').click()
  await page
    .getByTestId('query-period-picker')
    .getByRole('link', { name: 'Compare' })
    .click()

  const previousPeriodButton = page.getByRole('button', {
    name: 'Previous period'
  })

  await expect(previousPeriodButton).toBeVisible()

  const visitors = page.locator('#visitors')
  const previousVisitors = page.locator('#previous-visitors')

  await expect(visitors).toHaveText('2')
  await expect(previousVisitors).toHaveText('3')

  await previousPeriodButton.click()
  await page.getByRole('link', { name: 'Year over year' }).click()

  await expect(
    page.getByRole('button', { name: 'Year over year' })
  ).toBeVisible()

  await expect(visitors).toHaveText('2')
  await expect(previousVisitors).toHaveText('1')
})
