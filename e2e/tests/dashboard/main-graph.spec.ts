import { test, expect, type Page } from '@playwright/test'
import { setupSite, populateStats, addGoal } from '../fixtures'

type MetricCase = {
  selector: string
  expectedMetricLabel: string
  expectedBuckets: BucketExpectation[]
}
type BucketExpectation = [
  bucketIndex: number,
  timeLabel: string,
  metricValue: string
]

const MAIN_LINE = 'path.stroke-indigo-500[data-testid="graph-line"]'

async function hoverAndReadTooltip(page: Page, bucketIndex: number) {
  await page
    .locator(`[data-testid="graph-dot-group-${bucketIndex}"]`)
    .first()
    .hover()
  const tooltip = page.locator('[data-testid="graph-tooltip"]')
  await expect(tooltip).toBeVisible()
  return {
    metricLabel: await tooltip
      .locator('[data-testid="metric-label"]')
      .innerText(),
    mainTimeLabel: await tooltip
      .locator('[data-testid="main-time-label"]')
      .innerText(),
    mainValue: await tooltip.locator('[data-testid="main-value"]').innerText()
  }
}

test.describe('plotting all metrics', () => {
  // Time label rendering depends on locale. Set it to one with 24h clock
  test.use({ locale: 'en-GB' })

  test('default view', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 1,
          name: 'pageview',
          pathname: '/',
          timestamp: '2021-01-01 00:00:00'
        },
        {
          user_id: 1,
          name: 'pageview',
          pathname: '/page1',
          timestamp: '2021-01-01 00:10:00'
        },
        {
          user_id: 1,
          name: 'pageview',
          pathname: '/page2',
          timestamp: '2021-01-01 00:20:00'
        },
        {
          user_id: 2,
          name: 'pageview',
          pathname: '/',
          timestamp: '2021-01-01 05:00:00'
        }
      ]
    })

    await page.goto('/' + domain + '?period=day&date=2021-01-01', {
      waitUntil: 'commit'
    })

    const graphLine = page.locator(MAIN_LINE)
    await expect(graphLine).toBeVisible()

    const metricCases: MetricCase[] = [
      {
        selector: '#visitors',
        expectedMetricLabel: 'UNIQUE VISITORS',
        expectedBuckets: [
          [0, '00:00', '1'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#visits',
        expectedMetricLabel: 'TOTAL VISITS',
        expectedBuckets: [
          [0, '00:00', '1'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#pageviews',
        expectedMetricLabel: 'TOTAL PAGEVIEWS',
        expectedBuckets: [
          [0, '00:00', '3'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#views_per_visit',
        expectedMetricLabel: 'VIEWS PER VISIT',
        expectedBuckets: [
          [0, '00:00', '3'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#bounce_rate',
        expectedMetricLabel: 'BOUNCE RATE',
        expectedBuckets: [
          [0, '00:00', '0%'],
          [1, '01:00', '0%'],
          [5, '05:00', '100%']
        ]
      },
      {
        selector: '#visit_duration',
        expectedMetricLabel: 'VISIT DURATION',
        expectedBuckets: [
          [0, '00:00', '20m 00s'],
          [1, '01:00', '-'],
          [5, '05:00', '0s']
        ]
      }
    ]

    for (const {
      selector,
      expectedMetricLabel,
      expectedBuckets
    } of metricCases) {
      await test.step(expectedMetricLabel, async () => {
        await page.locator(selector).click()
        await expect(graphLine).toBeVisible()

        for (const [bucketIndex, timeLabel, metricValue] of expectedBuckets) {
          const tooltipInfo = await hoverAndReadTooltip(page, bucketIndex)
          expect(tooltipInfo.metricLabel).toBe(expectedMetricLabel)
          expect(
            tooltipInfo.mainTimeLabel,
            `Wrong time label for ${expectedMetricLabel}`
          ).toBe(timeLabel)
          expect(
            tooltipInfo.mainValue,
            `Wrong metric value for ${expectedMetricLabel} in ${timeLabel}`
          ).toBe(metricValue)
        }
      })
    }
  })

  test('goal-filtered view', async ({ page, request }) => {
    const goalName = 'Signup'
    const { domain } = await setupSite({ page, request })

    await addGoal({ request, domain, params: { event_name: goalName } })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 1,
          name: 'pageview',
          timestamp: '2021-01-01 00:00:00'
        },
        {
          user_id: 2,
          name: goalName,
          timestamp: '2021-01-01 10:00:00'
        },
        {
          user_id: 2,
          name: goalName,
          timestamp: '2021-01-01 10:10:00'
        },
        {
          user_id: 4,
          name: 'pageview',
          timestamp: '2021-01-01 10:00:00'
        },
        {
          user_id: 5,
          name: goalName,
          timestamp: '2021-01-01 23:00:00'
        }
      ]
    })

    await page.goto(
      '/' + domain + '?period=day&date=2021-01-01&f=is,goal,Signup',
      { waitUntil: 'commit' }
    )

    const graphLine = page.locator(MAIN_LINE)
    await expect(graphLine).toBeVisible()

    const metricCases: MetricCase[] = [
      {
        selector: '#visitors',
        expectedMetricLabel: 'UNIQUE CONVERSIONS',
        expectedBuckets: [
          [0, '00:00', '0'],
          [1, '01:00', '0'],
          [10, '10:00', '1'],
          [23, '23:00', '1']
        ]
      },
      {
        selector: '#events',
        expectedMetricLabel: 'TOTAL CONVERSIONS',
        expectedBuckets: [
          [0, '00:00', '0'],
          [1, '01:00', '0'],
          [10, '10:00', '2'],
          [23, '23:00', '1']
        ]
      },
      {
        selector: '#conversion_rate',
        expectedMetricLabel: 'CONVERSION RATE',
        expectedBuckets: [
          [0, '00:00', '0%'],
          [1, '01:00', '0%'],
          [10, '10:00', '50%'],
          [23, '23:00', '100%']
        ]
      }
    ]

    for (const {
      selector,
      expectedMetricLabel,
      expectedBuckets
    } of metricCases) {
      await test.step(expectedMetricLabel, async () => {
        await page.locator(selector).click()
        await expect(graphLine).toBeVisible()

        for (const [bucketIndex, timeLabel, metricValue] of expectedBuckets) {
          const tooltipInfo = await hoverAndReadTooltip(page, bucketIndex)
          expect(tooltipInfo.metricLabel).toBe(expectedMetricLabel)
          expect(
            tooltipInfo.mainTimeLabel,
            `Wrong time label for ${expectedMetricLabel}`
          ).toBe(timeLabel)
          expect(
            tooltipInfo.mainValue,
            `Wrong metric value for ${expectedMetricLabel} in ${timeLabel}`
          ).toBe(metricValue)
        }
      })
    }
  })

  test('page-filtered view', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 1,
          name: 'pageview',
          pathname: '/one',
          timestamp: '2021-01-01 00:00:00'
        },
        {
          user_id: 2,
          name: 'pageview',
          pathname: '/one',
          timestamp: '2021-01-01 05:30:00'
        },
        {
          user_id: 2,
          name: 'engagement',
          pathname: '/one',
          scroll_depth: 90,
          engagement_time: 20 * 60 * 1000,
          timestamp: '2021-01-01 05:50:00'
        },
        {
          user_id: 2,
          name: 'pageview',
          pathname: '/two',
          timestamp: '2021-01-01 05:50:00'
        },
        {
          user_id: 3,
          pathname: '/two',
          name: 'pageview',
          timestamp: '2021-01-01 00:00:00'
        }
      ]
    })

    await page.goto(
      '/' + domain + '?period=day&date=2021-01-01&f=is,page,/one',
      { waitUntil: 'commit' }
    )

    const graphLine = page.locator(MAIN_LINE)
    await expect(graphLine).toBeVisible()

    const metricCases: MetricCase[] = [
      {
        selector: '#visitors',
        expectedMetricLabel: 'UNIQUE VISITORS',
        expectedBuckets: [
          [0, '00:00', '1'],
          [5, '05:00', '1'],
          [10, '10:00', '0']
        ]
      },
      {
        selector: '#visits',
        expectedMetricLabel: 'TOTAL VISITS',
        expectedBuckets: [
          [0, '00:00', '1'],
          [5, '05:00', '1'],
          [10, '10:00', '0']
        ]
      },
      {
        selector: '#pageviews',
        expectedMetricLabel: 'TOTAL PAGEVIEWS',
        expectedBuckets: [
          [0, '00:00', '1'],
          [5, '05:00', '1'],
          [10, '10:00', '0']
        ]
      },
      {
        selector: '#bounce_rate',
        expectedMetricLabel: 'BOUNCE RATE',
        expectedBuckets: [
          [0, '00:00', '100%'],
          [5, '05:00', '0%'],
          [10, '10:00', '0%']
        ]
      },
      {
        selector: '#scroll_depth',
        expectedMetricLabel: 'SCROLL DEPTH',
        expectedBuckets: [
          [0, '00:00', '-'],
          [5, '05:00', '90%'],
          [10, '10:00', '-']
        ]
      },
      {
        selector: '#time_on_page',
        expectedMetricLabel: 'TIME ON PAGE',
        expectedBuckets: [
          [0, '00:00', '-'],
          [5, '05:00', '20m 00s'],
          [10, '10:00', '-']
        ]
      }
    ]

    for (const {
      selector,
      expectedMetricLabel,
      expectedBuckets
    } of metricCases) {
      await test.step(expectedMetricLabel, async () => {
        await page.locator(selector).click()
        await expect(
          graphLine,
          `Graph not visible after clicking ${selector}`
        ).toBeVisible()

        for (const [bucketIndex, timeLabel, metricValue] of expectedBuckets) {
          const tooltipInfo = await hoverAndReadTooltip(page, bucketIndex)
          expect(tooltipInfo.metricLabel).toBe(expectedMetricLabel)
          expect(
            tooltipInfo.mainTimeLabel,
            `Wrong time label for ${expectedMetricLabel}`
          ).toBe(timeLabel)
          expect(
            tooltipInfo.mainValue,
            `Wrong metric value for ${expectedMetricLabel} in ${timeLabel}`
          ).toBe(metricValue)
        }
      })
    }
  })
})
