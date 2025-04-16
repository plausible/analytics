import React from 'react'
import {
  render,
  screen,
  waitForElementToBeRemoved
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { stringifySearch } from '../../util/url-search-params'
import { useNavigate } from 'react-router-dom'
import { getRouterBasepath } from '../../router'
import { QueryPeriodsPicker } from './query-periods-picker'

const domain = 'picking-query-dates.test'
const periodStorageKey = `period__${domain}`

beforeAll(() => {
  global.ResizeObserver = jest.fn(
    () =>
      ({
        observe: jest.fn(),
        unobserve: jest.fn(),
        disconnect: jest.fn()
      }) as unknown as ResizeObserver
  )
})

test('if no period is stored, loads with default value of "Last 28 days", all expected options are present', async () => {
  expect(localStorage.getItem(periodStorageKey)).toBe(null)
  render(<QueryPeriodsPicker />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await userEvent.click(screen.getByText('Last 28 days'))

  expect(screen.getByTestId('datemenu')).toBeVisible()
  expect(screen.getAllByRole('link').map((el) => el.textContent)).toEqual(
    [
      ['Today', 'D'],
      ['Yesterday', 'E'],
      ['Realtime', 'R'],
      ['Last 7 Days', 'W'],
      ['Last 28 Days', 'F'],
      ['Last 91 Days', 'N'],
      ['Month to Date', 'M'],
      ['Last Month', 'P'],
      ['Year to Date', 'Y'],
      ['Last 12 Months', 'L'],
      ['All time', 'A'],
      ['Custom Range', 'C'],
      ['Compare', 'X']
    ].map((a) => a.join(''))
  )
})

test('user can select a new period and its value is stored', async () => {
  render(<QueryPeriodsPicker />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  expect(screen.queryByTestId('datemenu')).toBeNull()
  await userEvent.click(screen.getByText('Last 28 days'))
  expect(screen.getByTestId('datemenu')).toBeVisible()
  await userEvent.click(screen.getByText('All time'))
  await waitForElementToBeRemoved(() => screen.queryByTestId('datemenu'))
  expect(localStorage.getItem(periodStorageKey)).toBe('all')
})

test('period "all" is respected, and Compare option is not present for it in menu', async () => {
  localStorage.setItem(periodStorageKey, 'all')

  render(<QueryPeriodsPicker />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await userEvent.click(screen.getByText('All time'))
  expect(screen.getByTestId('datemenu')).toBeVisible()
  expect(screen.queryByText('Compare')).toBeNull()
})

test.each([
  [{ period: 'all' }, 'All time'],
  [{ period: 'month' }, 'Month to Date'],
  [{ period: 'year' }, 'Year to Date']
])(
  'the query period from search %p is respected and stored',
  async (searchRecord, buttonText) => {
    const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch(searchRecord)}`

    render(<QueryPeriodsPicker />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain }}
          routerProps={{ initialEntries: [startUrl] }}
          {...props}
        />
      )
    })

    expect(screen.getByText(buttonText)).toBeVisible()
    expect(localStorage.getItem(periodStorageKey)).toBe(searchRecord.period)
  }
)

test.each([
  [
    { period: 'custom', from: '2024-08-10', to: '2024-08-20' },
    '10 Aug - 20 Aug 24'
  ],
  [{ period: 'realtime' }, 'Realtime']
])(
  'the query period from search %p is respected but not stored',
  async (searchRecord, buttonText) => {
    const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch(searchRecord)}`

    render(<QueryPeriodsPicker />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain }}
          routerProps={{ initialEntries: [startUrl] }}
          {...props}
        />
      )
    })
    expect(screen.getByText(buttonText)).toBeVisible()
    expect(localStorage.getItem(periodStorageKey)).toBe(null)
  }
)

test.each([
  ['all', '7d', 'Last 7 days'],
  ['30d', 'month', 'Month to Date']
])(
  'if the stored period is %p but query period is %p, query is respected and the stored period is overwritten',
  async (storedPeriod, queryPeriod, buttonText) => {
    localStorage.setItem(periodStorageKey, storedPeriod)
    const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch({ period: queryPeriod })}`

    render(<QueryPeriodsPicker />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain, shared: false }}
          routerProps={{
            initialEntries: [startUrl]
          }}
          {...props}
        />
      )
    })

    await userEvent.click(screen.getByText(buttonText))
    expect(screen.getByTestId('datemenu')).toBeVisible()
    expect(localStorage.getItem(periodStorageKey)).toBe(queryPeriod)
  }
)

test('going back resets the stored query period to previous value', async () => {
  const BrowserBackButton = () => {
    const navigate = useNavigate()
    return (
      <button data-testid="browser-back" onClick={() => navigate(-1)}></button>
    )
  }
  render(
    <>
      <QueryPeriodsPicker />
      <BrowserBackButton />
    </>,
    {
      wrapper: (props) => (
        <TestContextProviders siteOptions={{ domain }} {...props} />
      )
    }
  )

  await userEvent.click(screen.getByText('Last 28 days'))
  await userEvent.click(screen.getByText('Year to Date'))
  await waitForElementToBeRemoved(() => screen.queryByTestId('datemenu'))

  expect(localStorage.getItem(periodStorageKey)).toBe('year')

  await userEvent.click(screen.getByText('Year to Date'))
  await userEvent.click(screen.getByText('Month to Date'))
  await waitForElementToBeRemoved(() => screen.queryByTestId('datemenu'))

  expect(localStorage.getItem(periodStorageKey)).toBe('month')

  await userEvent.click(screen.getByTestId('browser-back'))
  expect(screen.getByText('Year to Date')).toBeVisible()
  expect(localStorage.getItem(periodStorageKey)).toBe('year')
})
