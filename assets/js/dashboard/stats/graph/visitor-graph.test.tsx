import React from 'react'
import { render, waitForElementToBeRemoved } from '@testing-library/react'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import VisitorGraph from './visitor-graph'
import { MockAPI } from '../../../../test-utils/mock-api'

// jsdom doesn't implement ResizeObserver (used by useMainGraphWidth and useGuessTopStatsHeight)
global.ResizeObserver = class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
}

const LOADING_SPINNER = '[data-testid="loading-spinner"]'

const domain = 'dummy.site'
const queryPath = `/api/stats/${domain}/query/`
const metricStorageKey = `metric__${domain}`

// Default metrics shown in the top stats bar without any filter active
const DEFAULT_TOP_STATS_METRICS = [
  'visitors',
  'visits',
  'pageviews',
  'views_per_visit',
  'bounce_rate',
  'visit_duration'
]

function buildTopStatsResponse(metrics = DEFAULT_TOP_STATS_METRICS) {
  return {
    query: {
      metrics,
      dimensions: [],
      date_range: ['2024-01-01', '2024-01-28']
    },
    meta: {},
    results: [{ dimensions: [], metrics: metrics.map(() => 0) }]
  }
}

function buildMainGraphResponse(metric: string) {
  return {
    query: {
      metrics: [metric],
      dimensions: ['time:day'],
      date_range: ['2024-01-01', '2024-01-28']
    },
    meta: {
      time_labels: [],
      time_label_result_indices: [],
      partial_time_labels: null,
      comparison_partial_time_labels: null,
      empty_metrics: [0],
      present_index: 0
    },
    results: [],
    comparison_results: []
  }
}

let mockAPI: MockAPI

beforeAll(() => {
  mockAPI = new MockAPI().start()
})

afterAll(() => {
  mockAPI.stop()
})

beforeEach(() => {
  mockAPI.clear()
  localStorage.clear()
})

describe('main graph metric selection', () => {
  // sets up a single handler that returns either a top stats response (when
  // requested dimensions = []) or a graph response. Collects metrics that
  // have been requested by the graph into an array and returns it.
  function setupQueryHandler(topStatsMetrics = DEFAULT_TOP_STATS_METRICS) {
    const mainGraphCalledWithMetrics: string[] = []

    mockAPI.post(
      queryPath,
      async (_input: RequestInfo | URL, init?: RequestInit) => {
        const body = JSON.parse(init!.body as string) as {
          metrics: string[]
          dimensions: string[]
        }

        if (body.dimensions.length === 0) {
          return {
            status: 200,
            ok: true,
            json: async () => buildTopStatsResponse(topStatsMetrics)
          } as Response
        }

        const metric = body.metrics[0]
        mainGraphCalledWithMetrics.push(metric)
        return {
          status: 200,
          ok: true,
          json: async () => buildMainGraphResponse(metric)
        } as Response
      }
    )

    return { mainGraphCalledWithMetrics }
  }

  test('no stored metric → defaults to visitors, single graph request', async () => {
    const { mainGraphCalledWithMetrics } = setupQueryHandler()

    render(
      <TestContextProviders siteOptions={{ domain }}>
        <VisitorGraph />
      </TestContextProviders>
    )

    await waitForElementToBeRemoved(() =>
      document.querySelector(LOADING_SPINNER)
    )

    expect(mainGraphCalledWithMetrics).toEqual(['visitors'])
  })

  test('valid stored metric -> initial metric from storage, single graph request', async () => {
    localStorage.setItem(metricStorageKey, 'pageviews')
    const { mainGraphCalledWithMetrics } = setupQueryHandler()

    render(
      <TestContextProviders siteOptions={{ domain }}>
        <VisitorGraph />
      </TestContextProviders>
    )

    await waitForElementToBeRemoved(() =>
      document.querySelector(LOADING_SPINNER)
    )

    expect(mainGraphCalledWithMetrics).toEqual(['pageviews'])
  })

  test('invalid stored metric -> initial fetch with stored metric, corrected to default after top stats load', async () => {
    localStorage.setItem(metricStorageKey, 'scroll_depth')
    const { mainGraphCalledWithMetrics } = setupQueryHandler()

    render(
      <TestContextProviders siteOptions={{ domain }}>
        <VisitorGraph />
      </TestContextProviders>
    )

    await waitForElementToBeRemoved(() =>
      document.querySelector(LOADING_SPINNER)
    )

    expect(mainGraphCalledWithMetrics).toEqual(['scroll_depth', 'visitors'])
  })
})
