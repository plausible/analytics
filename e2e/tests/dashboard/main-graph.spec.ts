import { test, expect, Page } from '@playwright/test'
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

test.describe('plotting all metrics', () => {
  // Time label rendering depends on locale. Set it to one with 24h clock
  test.use({ locale: 'en-GB' })

  test('with no filters applied', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })
    const url = '/' + domain + '?period=day&date=2021-01-01'

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

    await page.goto(url, {
      waitUntil: 'commit'
    })

    const graphLine = mainSeriesLine(page)
    await expect(graphLine).toBeVisible()

    const metricCases: MetricCase[] = [
      {
        selector: '#visitors',
        expectedMetricLabel: 'Unique visitors',
        expectedBuckets: [
          [0, '00:00', '1'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#visits',
        expectedMetricLabel: 'Total visits',
        expectedBuckets: [
          [0, '00:00', '1'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#pageviews',
        expectedMetricLabel: 'Total pageviews',
        expectedBuckets: [
          [0, '00:00', '3'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#views_per_visit',
        expectedMetricLabel: 'Views per visit',
        expectedBuckets: [
          [0, '00:00', '3'],
          [1, '01:00', '0'],
          [5, '05:00', '1']
        ]
      },
      {
        selector: '#bounce_rate',
        expectedMetricLabel: 'Bounce rate',
        expectedBuckets: [
          [0, '00:00', '0%'],
          [1, '01:00', '0%'],
          [5, '05:00', '100%']
        ]
      },
      {
        selector: '#visit_duration',
        expectedMetricLabel: 'Visit duration',
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
      await test.step(`selecting ${expectedMetricLabel}`, async () => {
        await page.locator(selector).click()
        await expect(graphLine).toBeVisible()

        for (const [bucketIndex, timeLabel, metricValue] of expectedBuckets) {
          await mainSeriesDot(page, bucketIndex).hover()
          await expect(graphTooltip(page)).toHaveText(
            [
              expectedMetricLabel,
              timeLabel,
              metricValue,
              'Right click for more actions'
            ].join('')
          )
        }
      })
    }

    await test.step('keeps the last selected metric selected on page reload', async () => {
      await page.reload({ waitUntil: 'commit' })
      await expect(mainSeriesLine(page)).toBeVisible()
      await mainSeriesDot(page, 0).hover()
      await expect(graphTooltip(page)).toHaveText(
        [
          'Visit duration',
          '00:00',
          '20m 00s',
          'Right click for more actions'
        ].join('')
      )
    })

    await test.step('if the last selected metric is not available in the view on page reload, corrects it to default', async () => {
      const metricStorageKey = `metric__${domain}`
      // set stored metric that's invalid for this view
      await page.evaluate(
        (k) => localStorage.setItem(k, 'scroll_depth'),
        metricStorageKey
      )
      await page.reload({ waitUntil: 'commit' })
      await expect(mainSeriesLine(page)).toBeVisible()
      await mainSeriesDot(page, 0).hover()
      await expect(graphTooltip(page)).toHaveText(
        ['Unique visitors', '00:00', '1', 'Right click for more actions'].join(
          ''
        )
      )
    })
  })

  test('filtered by goal', async ({ page, request }) => {
    const goalName = 'Signup'
    const { domain } = await setupSite({ page, request })
    const url = '/' + domain + '?period=day&date=2021-01-01&f=is,goal,Signup'

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

    await page.goto(url, { waitUntil: 'commit' })

    const graphLine = mainSeriesLine(page)
    await expect(graphLine).toBeVisible()

    const metricCases: MetricCase[] = [
      {
        selector: '#visitors',
        expectedMetricLabel: 'Unique conversions',
        expectedBuckets: [
          [0, '00:00', '0'],
          [1, '01:00', '0'],
          [10, '10:00', '1'],
          [23, '23:00', '1']
        ]
      },
      {
        selector: '#events',
        expectedMetricLabel: 'Total conversions',
        expectedBuckets: [
          [0, '00:00', '0'],
          [1, '01:00', '0'],
          [10, '10:00', '2'],
          [23, '23:00', '1']
        ]
      },
      {
        selector: '#conversion_rate',
        expectedMetricLabel: 'Conversion rate',
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
      await test.step(`selecting ${expectedMetricLabel}`, async () => {
        await page.locator(selector).click()
        await expect(graphLine).toBeVisible()

        const tooltip = graphTooltip(page)
        for (const [bucketIndex, timeLabel, metricValue] of expectedBuckets) {
          await mainSeriesDot(page, bucketIndex).hover()
          await expect(tooltip).toHaveText(
            [
              expectedMetricLabel,
              timeLabel,
              metricValue,
              'Right click for more actions'
            ].join('')
          )
        }
      })
    }
  })

  test('filtered by page', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })
    const url = '/' + domain + '?period=day&date=2021-01-01&f=is,page,/one'

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

    await page.goto(url, { waitUntil: 'commit' })

    const graphLine = mainSeriesLine(page)
    await expect(graphLine).toBeVisible()

    const metricCases: MetricCase[] = [
      {
        selector: '#visitors',
        expectedMetricLabel: 'Unique visitors',
        expectedBuckets: [
          [0, '00:00', '1'],
          [5, '05:00', '1'],
          [10, '10:00', '0']
        ]
      },
      {
        selector: '#visits',
        expectedMetricLabel: 'Total visits',
        expectedBuckets: [
          [0, '00:00', '1'],
          [5, '05:00', '1'],
          [10, '10:00', '0']
        ]
      },
      {
        selector: '#pageviews',
        expectedMetricLabel: 'Total pageviews',
        expectedBuckets: [
          [0, '00:00', '1'],
          [5, '05:00', '1'],
          [10, '10:00', '0']
        ]
      },
      {
        selector: '#bounce_rate',
        expectedMetricLabel: 'Bounce rate',
        expectedBuckets: [
          [0, '00:00', '100%'],
          [5, '05:00', '0%'],
          [10, '10:00', '0%']
        ]
      },
      {
        selector: '#scroll_depth',
        expectedMetricLabel: 'Scroll depth',
        expectedBuckets: [
          [0, '00:00', '-'],
          [5, '05:00', '90%'],
          [10, '10:00', '-']
        ]
      },
      {
        selector: '#time_on_page',
        expectedMetricLabel: 'Time on page',
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
      await test.step(`selecting ${expectedMetricLabel}`, async () => {
        await page.locator(selector).click()
        await expect(graphLine).toBeVisible()

        for (const [bucketIndex, timeLabel, metricValue] of expectedBuckets) {
          await mainSeriesDot(page, bucketIndex).hover()
          await expect(graphTooltip(page)).toHaveText(
            [
              expectedMetricLabel,
              timeLabel,
              metricValue,
              'Right click for more actions'
            ].join('')
          )
        }
      })
    }
  })
})

const graphTooltip = (page: Page) => page.getByTestId('graph-tooltip')
const mainSeriesLine = (page: Page) => page.getByTestId('graph-line-series-1')
const mainSeriesDot = (page: Page, bucketIndex: number) =>
  page.getByTestId(`graph-dot-series-1-bucket-${bucketIndex}`)
