import { test, expect } from '@playwright/test'
import {
  ZonedDateTime,
  ZoneOffset,
  ChronoUnit,
  DateTimeFormatter
} from '@js-joda/core'
import { Locale } from '@js-joda/locale'
import { setupSite, populateStats } from '../fixtures.ts'

function timeToISO(ts: ZonedDateTime): string {
  return ts.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
}

test('site switcher allows switching between different sites', async ({
  page,
  request
}) => {
  const { domain: domain1, user } = await setupSite({ page, request })
  const { domain: domain2 } = await setupSite({ page, request, user })
  const { domain: domain3 } = await setupSite({ page, request, user })

  await populateStats({
    request,
    domain: domain1,
    events: [{ name: 'pageview' }]
  })
  await populateStats({
    request,
    domain: domain2,
    events: [{ name: 'pageview' }]
  })
  await populateStats({
    request,
    domain: domain3,
    events: [{ name: 'pageview' }]
  })

  await page.goto('/' + domain1)

  const switcherButton = page.getByTestId('site-switcher-current-site')

  await expect(switcherButton).toHaveText(domain1)

  await switcherButton.click()

  await expect(page.getByRole('link', { name: domain1 })).toBeVisible()
  await expect(page.getByRole('link', { name: domain2 })).toBeVisible()
  await expect(page.getByRole('link', { name: domain3 })).toBeVisible()

  await page.getByRole('link', { name: domain2 }).click()

  await expect(page).toHaveURL(`/${domain2}`)
  await expect(switcherButton).toHaveText(domain2)

  const sortedDomains = [domain1, domain2, domain3].sort()

  await page.keyboard.press('3')

  await expect(page).toHaveURL(`/${sortedDomains[2]}`)
  await expect(switcherButton).toHaveText(sortedDomains[2])

  await page.keyboard.press('1')

  await expect(page).toHaveURL(`/${sortedDomains[0]}`)
  await expect(switcherButton).toHaveText(sortedDomains[0])
})

test('current visitors counter shows number of active visitors', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })
  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', timestamp: { minutesAgo: 2 } },
      { name: 'pageview', timestamp: { minutesAgo: 3 } },
      { name: 'pageview', timestamp: { minutesAgo: 4 } },
      { name: 'pageview', timestamp: { minutesAgo: 5 } },
      { name: 'pageview', timestamp: { minutesAgo: 20 } },
      { name: 'pageview', timestamp: { minutesAgo: 50 } }
    ]
  })

  await page.goto('/' + domain)

  await expect(page.getByText('4 current visitors')).toBeVisible()
})

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
      timestamp: timeToISO(ts)
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

test('navigating dates previous next time periods', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  const now = ZonedDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS)
  const startOfDay = now.truncatedTo(ChronoUnit.DAYS)
  const startOfYesterday = startOfDay.minusDays(1)

  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', timestamp: timeToISO(now) },
      { name: 'pageview', timestamp: timeToISO(startOfDay.minusHours(3)) },
      { name: 'pageview', timestamp: timeToISO(startOfDay.minusHours(4)) },
      {
        name: 'pageview',
        timestamp: timeToISO(startOfYesterday.minusHours(3))
      },
      {
        name: 'pageview',
        timestamp: timeToISO(startOfYesterday.minusHours(4))
      },
      {
        name: 'pageview',
        timestamp: timeToISO(startOfYesterday.minusHours(5))
      }
    ]
  })

  await page.goto('/' + domain)

  const currentQueryPeriod = page.getByTestId('current-query-period')
  const queryPeriodPicker = page.getByTestId('query-period-picker')
  const backButton = queryPeriodPicker.getByTestId('period-move-back')
  const forwardButton = queryPeriodPicker.getByTestId('period-move-forward')
  const visitors = page.locator('#visitors')

  await currentQueryPeriod.click()
  await queryPeriodPicker.getByRole('link', { name: 'Today' }).click()

  await expect(currentQueryPeriod).toHaveText('Today')
  await expect(visitors).toHaveText('1')
  await expect(backButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(forwardButton).toHaveCSS('cursor', 'not-allowed')

  await backButton.click()

  const yesterdayLabel = startOfYesterday.format(
    DateTimeFormatter.ofPattern('EEE, d MMM').withLocale(Locale.ENGLISH)
  )

  await expect(currentQueryPeriod).toHaveText(yesterdayLabel)
  await expect(backButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(forwardButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(visitors).toHaveText('2')

  await backButton.click()

  const beforeYesterdayLabel = startOfYesterday
    .minusDays(1)
    .format(
      DateTimeFormatter.ofPattern('EEE, d MMM').withLocale(Locale.ENGLISH)
    )

  await expect(currentQueryPeriod).toHaveText(beforeYesterdayLabel)
  await expect(backButton).toHaveCSS('cursor', 'not-allowed')
  await expect(forwardButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(visitors).toHaveText('3')

  await forwardButton.click()

  await expect(currentQueryPeriod).toHaveText(yesterdayLabel)
  await expect(backButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(forwardButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(visitors).toHaveText('2')

  await forwardButton.click()

  await expect(currentQueryPeriod).toHaveText('Today')
  await expect(backButton).not.toHaveCSS('cursor', 'not-allowed')
  await expect(forwardButton).toHaveCSS('cursor', 'not-allowed')
  await expect(visitors).toHaveText('1')
})

test('selecting a custom date range', async ({ page, request }) => {
  const { domain } = await setupSite({ page, request })

  // NOTE: As the calendar renders contents dynamically, we cannot tell for sure
  // whether the day before today will be visible without switching month.
  // To make things simpler, we only test a single-day range of today.

  const now = ZonedDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS)
  const startOfDay = now.truncatedTo(ChronoUnit.DAYS)

  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', timestamp: timeToISO(now) },
      { name: 'pageview', timestamp: timeToISO(startOfDay.minusDays(3)) }
    ]
  })

  await page.goto('/' + domain)

  const currentQueryPeriod = page.getByTestId('current-query-period')
  const queryPeriodPicker = page.getByTestId('query-period-picker')
  const visitors = page.locator('#visitors')

  currentQueryPeriod.click()
  await queryPeriodPicker.getByRole('link', { name: 'Custom range' }).click()

  const todayLabel = startOfDay.format(
    DateTimeFormatter.ofPattern('MMMM d, YYYY').withLocale(Locale.ENGLISH)
  )

  await page.getByLabel(todayLabel).click()
  await page.getByLabel(todayLabel).click()

  await expect(currentQueryPeriod).toHaveText('Today')
  await expect(visitors).toHaveText('1')
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
