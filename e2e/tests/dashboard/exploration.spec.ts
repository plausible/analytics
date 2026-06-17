import { test, expect, Page, Locator } from '@playwright/test'
import { setupSite, populateStats, addGoal } from '../fixtures'
import { tabButton } from '../test-utils'

const getReport = (page: Page) => page.getByTestId('report-behaviours')
const getExplorationTabButton = (report: Locator) =>
  tabButton(report, 'Explore')

test('load user journey', async ({ page, request }) => {
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
        timestamp: { daysAgo: 7 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

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
  await expect(secondColumn).toHaveText(/Select a starting point to continue/)

  await firstColumn.getByRole('button', { name: '/page' }).click()

  await expect(
    firstColumn.getByRole('button', { name: '/page' })
  ).toHaveAttribute('data-exploration-step', '0')

  await expect(secondColumn).toHaveText(/No further steps found/)
})

test('load user journey and switch to a period with no events without waiting for load', async ({
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
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  // switch to 'Today'
  await page.keyboard.press('d')

  await expect(report).toHaveText(/No data yet/)
})

test('load user journey and switch to a period with no events', async ({
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
        timestamp: { daysAgo: 7 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

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

test('explore a 3-step funnel', async ({ page, request }) => {
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
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')
  const thirdColumn = report.getByTestId('exploration-column-2')

  await firstColumn.getByRole('button', { name: '/home' }).click()

  await expect(
    firstColumn.getByRole('button', { name: '/home' })
  ).toHaveAttribute('data-exploration-step', '0')

  await secondColumn.getByRole('button', { name: '/login' }).click()

  await expect(
    secondColumn.getByRole('button', { name: '/login' })
  ).toHaveAttribute('data-exploration-step', '1')

  await thirdColumn.getByRole('button', { name: '/dashboard' }).click()

  await expect(
    thirdColumn.getByRole('button', { name: '/dashboard' })
  ).toHaveAttribute('data-exploration-step', '2')

  await expect(firstColumn).toBeVisible()
  await expect(secondColumn).toBeVisible()
  await expect(thirdColumn).toBeVisible()

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/home', '/login', '/another', '/dashboard', '/journey'])

  await expect(
    firstColumn.getByRole('button', { name: '/home' })
  ).toHaveAttribute('data-exploration-step', '0')

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['3', '2', '1', '1', '1'])

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/login', 'No further action'])

  await expect(
    secondColumn.getByRole('button', { name: '/login' })
  ).toHaveAttribute('data-exploration-step', '1')

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['2', '1'])

  await expect(
    thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['No further action', '/dashboard'])

  await expect(
    thirdColumn.getByRole('button', { name: '/dashboard' })
  ).toHaveAttribute('data-exploration-step', '2')

  await expect(
    thirdColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['1', '1'])

  await expect(secondColumn).toHaveText(/1 step after/)
  await expect(thirdColumn).toHaveText(/2 steps after/)

  await test.step('Deselecting all resets the journey', async () => {
    await report.getByTestId('exploration-deselect-all').click()

    await expect(secondColumn).toHaveText(/Select a starting point to continue/)
    await expect(thirdColumn).toHaveText(/Select an event to continue/)

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home', '/login', '/another', '/dashboard', '/journey'])

    await expect(
      firstColumn.getByRole('button', { name: '/dashboard' })
    ).not.toHaveAttribute('data-exploration-step')
  })
})

test('select entries in a 1-step journey', async ({ page, request }) => {
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
        pathname: '/another-home',
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
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')

  await expect(secondColumn).toHaveText(/Select a starting point to continue/)

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/home', '/login', '/another-home', '/dashboard', '/journey'])

  await expect(
    firstColumn.getByRole('button', { name: '/home' })
  ).not.toHaveAttribute('data-exploration-step', '0')

  await test.step('select an entry', async () => {
    await firstColumn.getByRole('button', { name: '/login' }).click()

    await expect(
      firstColumn.getByRole('button', { name: '/login' })
    ).toHaveAttribute('data-exploration-step', '0')

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['No further action', '/dashboard'])
  })

  await test.step('select a different entry', async () => {
    await firstColumn.getByRole('button', { name: '/another' }).click()

    await expect(
      firstColumn.getByRole('button', { name: '/another-home' })
    ).toHaveAttribute('data-exploration-step', '0')

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/journey'])
  })

  await test.step('select a different entry with no further steps', async () => {
    await firstColumn.getByRole('button', { name: '/dashboard' }).click()

    await expect(
      firstColumn.getByRole('button', { name: '/dashboard' })
    ).toHaveAttribute('data-exploration-step', '0')

    await expect(secondColumn).toHaveText(/No further steps found/)
  })

  await test.step('deselect an entry', async () => {
    await firstColumn.getByRole('button', { name: '/dashboard' }).click()

    await expect(
      firstColumn.getByRole('button', { name: '/dashboard' })
    ).not.toHaveAttribute('data-exploration-step', '0')

    await expect(secondColumn).toHaveText(/Select a starting point to continue/)
  })

  await test.step('filter entries with match', async () => {
    await firstColumn.getByPlaceholder('Search').fill('dash')

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/dashboard'])
  })

  await test.step('filter entries with no match', async () => {
    await firstColumn.getByPlaceholder('Search').fill('nosuchthing')

    await expect(firstColumn).toHaveText(/No events found/)
  })

  await test.step('filter returning more than one entry', async () => {
    await firstColumn.getByPlaceholder('Search').fill('home')

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home', '/another-home'])
  })

  await test.step('select an entry with filtering applied', async () => {
    await firstColumn.getByRole('button', { name: '/home' }).click()

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login', 'No further action'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home', '/another-home'])

    await expect(
      firstColumn.getByRole('button', { name: '/home' })
    ).toHaveAttribute('data-exploration-step', '0')
  })

  await test.step('select another entry with filtering still applied', async () => {
    await firstColumn.getByRole('button', { name: '/another-home' }).click()

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/journey'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home', '/another-home'])

    await expect(
      firstColumn.getByRole('button', { name: '/another-home' })
    ).toHaveAttribute('data-exploration-step', '0')
  })

  await test.step('deselect an entry with filtering still applied', async () => {
    await firstColumn.getByRole('button', { name: '/another-home' }).click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home', '/login', '/another-home', '/dashboard', '/journey'])

    await expect(
      firstColumn.getByRole('button', { name: '/another-home' })
    ).not.toHaveAttribute('data-exploration-step', '0')

    await expect(secondColumn).toHaveText(/Select a starting point to continue/)
  })
})

test('select entries in a 3-step journey', async ({ page, request }) => {
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
        user_id: 124,
        name: 'pageview',
        pathname: '/logout',
        timestamp: { minutesAgo: 25 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/login',
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/dashboard',
        timestamp: { minutesAgo: 25 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/another-home',
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/journey',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/somewhere',
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 127,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 127,
        name: 'pageview',
        pathname: '/blog',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 128,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 40 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')
  const thirdColumn = report.getByTestId('exploration-column-2')
  const fourthColumn = report.getByTestId('exploration-column-3')

  await expect(secondColumn).toHaveText(/Select a starting point to continue/)

  await firstColumn.getByRole('button', { name: '/home' }).click()

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/login', 'No further action', '/blog'])

  await test.step('filter for "No further action" in the second step', async () => {
    await secondColumn.getByPlaceholder('Search').fill('no further')

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['No further action'])
  })

  await secondColumn.getByPlaceholder('Search').fill('')

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/login', 'No further action', '/blog'])

  await test.step('select an entry in the 2nd step', async () => {
    await secondColumn.getByRole('button', { name: '/login' }).click()

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/dashboard', '/logout'])

    await expect(
      secondColumn.getByRole('button', { name: '/login' })
    ).toHaveAttribute('data-exploration-step', '1')
  })

  await test.step('select a different entry in the 2nd step', async () => {
    await secondColumn.getByRole('button', { name: '/blog' }).click()

    await expect(thirdColumn).toHaveText(/No further steps found/)

    await expect(
      secondColumn.getByRole('button', { name: '/blog' })
    ).toHaveAttribute('data-exploration-step', '1')
  })

  await test.step('deselect an entry in the 2nd step', async () => {
    await secondColumn.getByRole('button', { name: '/blog' }).click()

    await expect(thirdColumn).toHaveText(/Select an event to continue/)

    await expect(
      secondColumn.getByRole('button', { name: '/blog' })
    ).not.toHaveAttribute('data-exploration-step', '1')

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login', 'No further action', '/blog'])
  })

  await test.step('select a different entry in the 1st step', async () => {
    await firstColumn.getByRole('button', { name: '/another-home' }).click()

    await expect(
      firstColumn.getByRole('button', { name: '/another-home' })
    ).toHaveAttribute('data-exploration-step', '0')

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/journey'])

    await expect(thirdColumn).toHaveText(/Select an event to continue/)
  })

  await test.step('select an entry in the 2nd step and 3rd step', async () => {
    await secondColumn.getByRole('button', { name: '/journey' }).click()

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/somewhere'])

    await thirdColumn.getByRole('button', { name: '/somewhere' }).click()

    await expect(fourthColumn).toHaveText(/No further steps found/)
  })

  await test.step('deselect an entry at the 1st step', async () => {
    await firstColumn.getByRole('button', { name: '/another-home' }).click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText([
      '/home',
      '/login',
      '/dashboard',
      '/another-home',
      '/blog',
      '/journey',
      '/logout',
      '/somewhere'
    ])

    await expect(
      firstColumn.getByRole('button', { name: '/another-home' })
    ).not.toHaveAttribute('data-exploration-step', '0')

    await expect(secondColumn).toHaveText(/Select a starting point to continue/)

    await expect(thirdColumn).toHaveText(/Select an event to continue/)

    await expect(fourthColumn).toBeHidden()
  })
})

test('explore journey hitting 20 step limit', async ({ page, request }) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  const events = [...Array(21).keys()].map((i) => {
    return {
      user_id: 123,
      name: 'pageview',
      pathname: `/page${i}`,
      timestamp: { minutesAgo: 100 - i }
    }
  })

  await populateStats({ request, domain, events })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const lastColumn = report.getByTestId('exploration-column-20')

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText([
    '/page0',
    '/page1',
    '/page10',
    '/page11',
    '/page12',
    '/page13',
    '/page14',
    '/page15',
    '/page16',
    '/page17'
  ])

  await (async () => {
    for await (const i of [...Array(20).keys()]) {
      const column = report.getByTestId(`exploration-column-${i}`)

      await column.getByRole('button', { name: `/page${i}` }).click()

      await expect(
        column.getByRole('button', { name: `/page${i}` })
      ).toHaveAttribute('data-exploration-step', `${i}`)
    }
  })()

  await expect(lastColumn).toHaveText(
    /You've reached the maximum journey depth/
  )
})

test('explore from end point', async ({ page, request }) => {
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
        user_id: 124,
        name: 'pageview',
        pathname: '/logout',
        timestamp: { minutesAgo: 25 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/login',
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 125,
        name: 'pageview',
        pathname: '/dashboard',
        timestamp: { minutesAgo: 25 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/another-home',
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/journey',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 126,
        name: 'pageview',
        pathname: '/somewhere',
        timestamp: { minutesAgo: 30 }
      },
      {
        user_id: 127,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 40 }
      },
      {
        user_id: 127,
        name: 'pageview',
        pathname: '/blog',
        timestamp: { minutesAgo: 35 }
      },
      {
        user_id: 128,
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 40 }
      }
    ]
  })

  const firstStepSuggestions = [
    '/home',
    '/login',
    '/dashboard',
    '/another-home',
    '/blog',
    '/journey',
    '/logout',
    '/somewhere'
  ]

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')
  const thirdColumn = report.getByTestId('exploration-column-2')
  const fourthColumn = report.getByTestId('exploration-column-3')

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(firstStepSuggestions)

  await test.step('switch to end point, back to start point and to end point again', async () => {
    await report.getByTestId('exploration-direction-forward').click()
    await report.getByTestId('exploration-direction-backward').click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(firstStepSuggestions)

    await expect(
      firstColumn.getByRole('button', { name: '/home' })
    ).not.toHaveAttribute('data-exploration-step', '0')

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(firstStepSuggestions)

    await expect(secondColumn).toHaveText(/1 step before/)
    await expect(secondColumn).toHaveText(/Select an end point to continue/)
    await expect(thirdColumn).toHaveText(/2 steps before/)
    await expect(thirdColumn).toHaveText(/Select an event to continue/)
    await expect(fourthColumn).toBeHidden()

    await report.getByTestId('exploration-direction-backward').click()
    await report.getByTestId('exploration-direction-forward').click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(firstStepSuggestions)

    await expect(secondColumn).toHaveText(/1 step after/)
    await expect(secondColumn).toHaveText(/Select a starting point to continue/)
    await expect(thirdColumn).toHaveText(/2 steps after/)
    await expect(thirdColumn).toHaveText(/Select an event to continue/)
    await expect(fourthColumn).toBeHidden()
  })

  await test.step('explore a 3-step journey from an end point', async () => {
    await report.getByTestId('exploration-direction-forward').click()
    await report.getByTestId('exploration-direction-backward').click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(firstStepSuggestions)

    await firstColumn.getByRole('button', { name: '/dashboard' }).click()

    await expect(
      firstColumn.getByRole('button', { name: '/dashboard' })
    ).toHaveAttribute('data-exploration-step', '0')

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login'])

    await expect(thirdColumn).toHaveText(/Select an event to continue/)

    await secondColumn.getByRole('button', { name: '/login' }).click()

    await expect(
      secondColumn.getByRole('button', { name: '/login' })
    ).toHaveAttribute('data-exploration-step', '1')

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home'])

    await thirdColumn.getByRole('button', { name: '/home' }).click()

    await expect(
      thirdColumn.getByRole('button', { name: '/home' })
    ).toHaveAttribute('data-exploration-step', '2')

    await expect(fourthColumn).toHaveText(/No further steps found/)
  })

  await test.step('switch back to starting point', async () => {
    await report.getByTestId('exploration-direction-backward').click()
    await report.getByTestId('exploration-direction-forward').click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(firstStepSuggestions)
  })
})

test('change filters during a 3-step journey', async ({ page, request }) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 123,
        browser: 'Firefox',
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 20 }
      },
      {
        user_id: 123,
        browser: 'Firefox',
        name: 'pageview',
        pathname: '/login',
        timestamp: { minutesAgo: 19 }
      },
      {
        user_id: 123,
        browser: 'Chrome',
        name: 'pageview',
        pathname: '/dashboard',
        timestamp: { minutesAgo: 18 }
      },
      {
        user_id: 124,
        browser: 'Chrome',
        name: 'pageview',
        pathname: '/home',
        timestamp: { minutesAgo: 20 }
      },
      {
        user_id: 124,
        browser: 'Chrome',
        name: 'pageview',
        pathname: '/login',
        timestamp: { minutesAgo: 19 }
      },
      {
        user_id: 125,
        browser: 'Safari',
        name: 'pageview',
        pathname: '/other',
        timestamp: { minutesAgo: 20 }
      },
      {
        user_id: 125,
        browser: 'Safari',
        name: 'pageview',
        pathname: '/journey',
        timestamp: { minutesAgo: 19 }
      }
    ]
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')
  const secondColumn = report.getByTestId('exploration-column-1')
  const thirdColumn = report.getByTestId('exploration-column-2')
  const fourthColumn = report.getByTestId('exploration-column-3')

  await firstColumn.getByRole('button', { name: '/home' }).click()

  await expect(
    firstColumn.getByRole('button', { name: '/home' })
  ).toHaveAttribute('data-exploration-step', '0')

  await secondColumn.getByRole('button', { name: '/login' }).click()

  await expect(
    secondColumn.getByRole('button', { name: '/login' })
  ).toHaveAttribute('data-exploration-step', '1')

  await thirdColumn.getByRole('button', { name: '/dashboard' }).click()

  await expect(
    thirdColumn.getByRole('button', { name: '/dashboard' })
  ).toHaveAttribute('data-exploration-step', '2')

  await expect(fourthColumn).toHaveText(/No further steps found/)

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/home', '/login', '/dashboard', '/journey', '/other'])

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['2', '2', '1', '1', '1'])

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['/login'])

  await expect(
    secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['2'])

  await expect(
    thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(['No further action', '/dashboard'])

  await expect(
    thirdColumn.getByTestId('exploration-row').getByTestId('metric-value')
  ).toHaveText(['1', '1'])

  await test.step('filtering with journey matches in all 3 steps', async () => {
    // filter by 'Firefox' browser
    await page
      .getByTestId('report-devices')
      .getByRole('link', { name: 'Firefox' })
      .click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2'])

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/dashboard'])

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['1'])

    await expect(fourthColumn).toHaveText(/No further steps found/)

    // remove the filter
    page
      .getByRole('button', { name: 'Remove filter: Browser is Firefox' })
      .click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2'])

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/dashboard'])

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['1'])

    await expect(fourthColumn).toHaveText(/No further steps found/)
  })

  await test.step('filtering with journey matches for 2 first steps', async () => {
    // filter by 'Chrome' browser
    await page
      .getByTestId('report-devices')
      .getByRole('link', { name: 'Chrome' })
      .click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['1'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['1'])

    await expect(thirdColumn).toHaveText(/No further steps found/)

    await expect(fourthColumn).toBeHidden()

    // remove the filter
    page
      .getByRole('button', { name: 'Remove filter: Browser is Chrome' })
      .click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/login'])

    await expect(
      secondColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2'])

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['No further action', '/dashboard'])

    await expect(
      thirdColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['1', '1'])

    await expect(
      thirdColumn.getByRole('button', { name: '/dashboard' })
    ).not.toHaveAttribute('data-exploration-step', '2')

    await expect(fourthColumn).toBeHidden()
  })

  // select the 3rd step again
  await thirdColumn.getByRole('button', { name: '/dashboard' }).click()

  await expect(
    thirdColumn.getByRole('button', { name: '/dashboard' })
  ).toHaveAttribute('data-exploration-step', '2')

  await test.step('filtering with journey with no matches for any of the steps', async () => {
    // filter by 'Chrome' browser
    await page
      .getByTestId('report-devices')
      .getByRole('link', { name: 'Safari' })
      .click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/journey', '/other'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['1', '1'])

    await expect(secondColumn).toHaveText(/Select a starting point to continue/)

    await expect(thirdColumn).toHaveText(/Select an event to continue/)

    await expect(fourthColumn).toBeHidden()

    // remove the filter
    page
      .getByRole('button', { name: 'Remove filter: Browser is Safari' })
      .click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(['/home', '/login', '/dashboard', '/journey', '/other'])

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-value')
    ).toHaveText(['2', '2', '1', '1', '1'])

    await expect(secondColumn).toHaveText(/Select a starting point to continue/)

    await expect(thirdColumn).toHaveText(/Select an event to continue/)

    await expect(fourthColumn).toBeHidden()
  })
})

test('render various types of entries', async ({ page, request }) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  await populateStats({
    request,
    domain,
    events: [
      {
        name: 'pageview',
        pathname: '/home'
      },
      {
        name: 'pageview',
        pathname: '/login'
      },
      {
        name: 'checkout'
      },
      {
        name: 'create_site'
      },
      {
        name: 'pageview',
        pathname: '/blog/first-post'
      },
      {
        name: 'pageview',
        pathname: '/blog/second-post'
      }
    ]
  })

  await addGoal({
    request,
    domain,
    params: { event_name: 'create_site', display_name: 'Create a site' }
  })

  await addGoal({ request, domain, params: { page_path: '/login' } })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText([
    '/blog',
    'checkout',
    'Create a site',
    '/blog/first-post',
    '/blog/second-post',
    '/home',
    'Visit /login'
  ])

  await firstColumn.getByTestId('exploration-row').nth(0).locator('svg').hover()
  await expect(page.getByRole('tooltip')).toHaveText(
    /Grouped pages: 2 pages with this prefix/
  )

  await firstColumn.getByTestId('exploration-row').nth(2).locator('svg').hover()
  await expect(page.getByRole('tooltip')).toHaveText(/Goal/)

  await firstColumn.getByTestId('exploration-row').nth(6).locator('svg').hover()
  await expect(page.getByRole('tooltip')).toHaveText(/Goal/)
})

test('load more suggestions', async ({ page, request }) => {
  const report = getReport(page)
  const explorationTabButton = getExplorationTabButton(report)
  const { domain } = await setupSite({ page, request })

  const events1 = [...Array(25).keys()].map((i) => {
    return {
      name: 'pageview',
      pathname: `/pageone${String(i).padStart(2, '0')}`
    }
  })

  const events2 = [...Array(25).keys()].map((i) => {
    return {
      name: 'pageview',
      pathname: `/pagetwo${String(i).padStart(2, '0')}`
    }
  })

  await populateStats({
    request,
    domain,
    events: events1.concat(events2)
  })

  await page.goto('/' + domain, { waitUntil: 'commit' })

  await explorationTabButton.click()
  await report.getByTestId('report-end').scrollIntoViewIfNeeded()

  await expect(report.getByTestId('exploration-title')).toHaveText(
    'Explore user journeys'
  )

  await expect(
    report.getByTestId('exploration-direction-forward')
  ).toBeVisible()

  const firstColumn = report.getByTestId('exploration-column-0')

  const columnRow = (i: number) =>
    firstColumn.getByTestId('exploration-row').nth(i)

  const firstPage = [
    '/pageone00',
    '/pageone01',
    '/pageone02',
    '/pageone03',
    '/pageone04',
    '/pageone05',
    '/pageone06',
    '/pageone07',
    '/pageone08',
    '/pageone09'
  ]

  const secondPage = [
    '/pageone10',
    '/pageone11',
    '/pageone12',
    '/pageone13',
    '/pageone14',
    '/pageone15',
    '/pageone16',
    '/pageone17',
    '/pageone18',
    '/pageone19'
  ]

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(firstPage)

  await expect(columnRow(10)).toHaveText(/Show 10 more/)
  await columnRow(10).click()

  await expect(
    firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
  ).toHaveText(firstPage.concat(secondPage))

  await expect(columnRow(20)).toHaveText(/Show 10 more/)

  await test.step('reset state when suggestions change', async () => {
    await firstColumn.getByPlaceholder('Search').fill('pagetwo')

    const newFirstPage = [
      '/pagetwo00',
      '/pagetwo01',
      '/pagetwo02',
      '/pagetwo03',
      '/pagetwo04',
      '/pagetwo05',
      '/pagetwo06',
      '/pagetwo07',
      '/pagetwo08',
      '/pagetwo09'
    ]

    const newSecondPage = [
      '/pagetwo10',
      '/pagetwo11',
      '/pagetwo12',
      '/pagetwo13',
      '/pagetwo14',
      '/pagetwo15',
      '/pagetwo16',
      '/pagetwo17',
      '/pagetwo18',
      '/pagetwo19'
    ]

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(newFirstPage)

    await expect(columnRow(10)).toHaveText(/Show 10 more/)
    await columnRow(10).click()

    await expect(
      firstColumn.getByTestId('exploration-row').getByTestId('metric-label')
    ).toHaveText(newFirstPage.concat(newSecondPage))

    await expect(columnRow(20)).toHaveText(/Show 5 more/)
  })
})
