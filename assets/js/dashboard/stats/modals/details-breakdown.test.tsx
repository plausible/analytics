import React, { useState, Dispatch, SetStateAction } from 'react'
import { act, render, screen, fireEvent } from '@testing-library/react'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { PagesDetails } from '../pages/details'
import { MockAPI } from '../../../../test-utils/mock-api'
import { PAGINATION_LIMIT } from '../../hooks/api-client'
import { QueryApiResponse } from '../../api'
import { StatsQuery } from '../../stats-query'
import { DEBOUNCE_DELAY } from '../../custom-hooks'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'

const domain = 'dummy.site'
const queryPath = `/api/stats/${domain}/query/`
const MOCK_RESPONSE_DELAY_MS = 50
const SMALL_LOADING_SPINNER_TEST_ID = 'small-loading-spinner'

const PAGES_DETAILED_METRICS = BREAKDOWN_REPORTS.pages.getMetrics({
  isDetailed: true,
  isRealtime: false,
  hasConversionGoalFilter: false,
  isRevenueAvailable: false
})

function buildResponse(
  results: { dimensions: string[]; metrics: number[] }[] = []
): QueryApiResponse {
  return {
    results,
    meta: {},
    query: {
      metrics: PAGES_DETAILED_METRICS,
      dimensions: ['event:page'],
      date_range: ['2024-01-01', '2024-01-28']
    },
    extraContext: { isRealtime: false, hasConversionGoalFilter: false }
  }
}

function buildFullPage(offset: number) {
  return Array.from({ length: PAGINATION_LIMIT }, (_, i) => {
    return {
      dimensions: [`/page-${offset + i}`],
      metrics: PAGES_DETAILED_METRICS.map((_metric) => 1)
    }
  })
}

function setupQueryHandler({ delay = false } = {}) {
  const requestBodies: StatsQuery[] = []

  mockAPI.post(
    queryPath,
    async (_input: RequestInfo | URL, init?: RequestInit) => {
      const body = JSON.parse(init!.body as string) as StatsQuery
      requestBodies.push(body)

      if (delay) {
        await new Promise((resolve) =>
          setTimeout(resolve, MOCK_RESPONSE_DELAY_MS)
        )
      }

      const results = buildFullPage(body.pagination?.offset || 0)
      return {
        status: 200,
        ok: true,
        json: async () => buildResponse(results)
      } as Response
    }
  )

  return { requestBodies }
}

// TanStack Query batches React state updates via a deferred setTimeout(cb, 0).
// This fires that callback so React sees the updated query state.
function flushTanStackNotification() {
  act(() => jest.advanceTimersByTime(10))
}

// Advance timers and flush microtasks until all pending React state updates settle.
async function settle() {
  // fire the mock response delay
  act(() => jest.advanceTimersByTime(MOCK_RESPONSE_DELAY_MS + 10))
  // drain Promise chains inside TanStack Query
  await act(async () => {})
  flushTanStackNotification()
}

async function expectAndAwaitLoading() {
  flushTanStackNotification()
  expect(screen.getByTestId(SMALL_LOADING_SPINNER_TEST_ID)).toBeVisible()
  await settle()
  expect(
    screen.queryByTestId(SMALL_LOADING_SPINNER_TEST_ID)
  ).not.toBeInTheDocument()
}

function expectNotLoading() {
  flushTanStackNotification()
  expect(
    screen.queryByTestId(SMALL_LOADING_SPINNER_TEST_ID)
  ).not.toBeInTheDocument()
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
  jest.useFakeTimers()
  const modalRoot = document.createElement('div')
  modalRoot.setAttribute('id', 'modal_root')
  document.body.appendChild(modalRoot)
})

afterEach(() => {
  jest.useRealTimers()
  document.getElementById('modal_root')?.remove()
})

function renderModal() {
  let toggle: Dispatch<SetStateAction<boolean>>

  function ToggleableModal() {
    const [open, s] = useState(false)
    toggle = s
    return open ? (
      <PagesDetails breakdownReportKey={BreakdownReportKey.pages} />
    ) : null
  }

  render(
    <TestContextProviders siteOptions={{ domain }}>
      <ToggleableModal />
    </TestContextProviders>
  )

  return {
    open: async () => {
      act(() => toggle(true))
      await settle()
    },
    close: async () => {
      act(() => toggle(false))
      await settle()
    }
  }
}

test('opening the modal for a second time with the same dashboardState gets response from cache', async () => {
  const { requestBodies } = setupQueryHandler()
  const { open, close } = renderModal()

  await open()
  expect(screen.getByText('Top pages')).toBeVisible()
  expect(requestBodies).toHaveLength(1)

  await close()
  await open()
  expect(screen.getByText('Top pages')).toBeVisible()
  expect(requestBodies).toHaveLength(1)
})

test('debounced search input adds a contains filter', async () => {
  const { requestBodies } = setupQueryHandler({ delay: true })
  const { open } = renderModal()
  await open()
  expect(screen.getByText('Top pages')).toBeVisible()

  const changeSearchInput = (value: string) => {
    fireEvent.change(screen.getByRole('textbox'), { target: { value } })
  }

  for (const s of ['/', '/b', '/bl', '/blo', '/blog']) {
    changeSearchInput(s)
  }

  act(() => jest.advanceTimersByTime(DEBOUNCE_DELAY))

  await expectAndAwaitLoading()

  expect(requestBodies).toHaveLength(2)
  expect(requestBodies[1]).toMatchObject({
    filters: [['contains', 'event:page', ['/blog'], { case_sensitive: false }]]
  })
})

test('load more button fetches the next page with correct offset', async () => {
  const { requestBodies } = setupQueryHandler({ delay: true })
  const { open } = renderModal()
  await open()

  expect(screen.getByText('Top pages')).toBeVisible()
  expect(screen.getByText('Load more')).toBeVisible()

  act(() => fireEvent.click(screen.getByText('Load more')))

  await expectAndAwaitLoading()

  expect(requestBodies).toHaveLength(2)
  expect(requestBodies[0]).toMatchObject({
    pagination: { limit: PAGINATION_LIMIT, offset: 0 }
  })
  expect(requestBodies[1]).toMatchObject({
    pagination: { limit: PAGINATION_LIMIT, offset: PAGINATION_LIMIT }
  })
})

test('clicking a column header cycles sort direction', async () => {
  const { requestBodies } = setupQueryHandler({ delay: true })
  const { open } = renderModal()
  await open()

  expect(screen.getByText('Top pages')).toBeVisible()
  expect(screen.getByRole('button', { name: /visitors/i })).toBeVisible()

  act(() => fireEvent.click(screen.getByRole('button', { name: /visitors/i })))

  await expectAndAwaitLoading()

  expect(requestBodies).toHaveLength(2)
  expect(requestBodies[0]).toMatchObject({
    order_by: [
      ['visitors', 'desc'],
      ['event:page', 'asc']
    ]
  })
  expect(requestBodies[1]).toMatchObject({
    order_by: [
      ['visitors', 'asc'],
      ['event:page', 'asc']
    ]
  })
})

test('toggling sort back to the original direction gets results from cache', async () => {
  const { requestBodies } = setupQueryHandler({ delay: true })
  const { open } = renderModal()
  await open()

  expect(screen.getByRole('button', { name: /visitors/i })).toBeVisible()

  act(() => fireEvent.click(screen.getByRole('button', { name: /visitors/i })))
  await expectAndAwaitLoading()
  expect(requestBodies).toHaveLength(2)

  // cache hit — no loading spinner, no request made
  act(() => fireEvent.click(screen.getByRole('button', { name: /visitors/i })))
  expectNotLoading()
  expect(requestBodies).toHaveLength(2)
})

test('clearing search gets results from cache', async () => {
  const { requestBodies } = setupQueryHandler({ delay: true })
  const { open } = renderModal()
  await open()

  expect(screen.getByText('Top pages')).toBeVisible()

  const changeSearchInput = (value: string) => {
    fireEvent.change(screen.getByRole('textbox'), { target: { value } })
  }

  changeSearchInput('/blog')
  act(() => jest.advanceTimersByTime(DEBOUNCE_DELAY))
  await expectAndAwaitLoading()
  expect(requestBodies).toHaveLength(2)

  changeSearchInput('')
  act(() => jest.advanceTimersByTime(DEBOUNCE_DELAY))
  expectNotLoading()
  expect(requestBodies).toHaveLength(2)
})
