import React from 'react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { MockAPI } from '../../../../test-utils/mock-api'
import { getRouterBasepath } from '../../router'
import { stringifySearch } from '../../util/url-search-params'
import FilterModalRow from './filter-modal-row'

const domain = 'dummy.site'
const suggestionsPath = `/api/stats/${domain}/suggestions/city/`

const TOKYO = { value: 1850147, label: 'Tokyo' }
const MILAN = { value: 3173435, label: 'Milan' }

let mockAPI: MockAPI

beforeAll(() => {
  mockAPI = new MockAPI().start()
})

afterAll(() => {
  mockAPI.stop()
})

beforeEach(() => {
  mockAPI.clear()
})

// A city filter that came from the URL: clauses are strings, since that's
// what parsing the search params yields.
const appliedCityFilter = ['is', 'city', [String(TOKYO.value)]]

function renderRow({
  onUpdate = jest.fn(),
  filter = appliedCityFilter
}: {
  onUpdate?: jest.Mock
  filter?: unknown
} = {}) {
  const searchRecord = {
    filters: [appliedCityFilter],
    labels: { [String(TOKYO.value)]: TOKYO.label }
  }

  render(
    <TestContextProviders
      siteOptions={{ domain }}
      routerProps={{
        initialEntries: [
          `${getRouterBasepath({ domain, shared: false })}${stringifySearch(searchRecord)}`
        ]
      }}
    >
      <FilterModalRow
        testId="city"
        filter={filter}
        labels={searchRecord.labels}
        canDelete={false}
        showDelete={false}
        onUpdate={onUpdate}
        onDelete={jest.fn()}
      />
    </TestContextProviders>
  )

  return { onUpdate }
}

describe('FilterModalRow (city)', () => {
  test('selecting an extra city keeps every clause a string, so follow-up suggestion queries stay valid', async () => {
    const suggestions = mockAPI.get(
      suggestionsPath,
      async () =>
        ({ status: 200, ok: true, json: async () => [MILAN] }) as Response
    )
    const { onUpdate } = renderRow()

    await userEvent.click(screen.getByPlaceholderText('Select a City'))
    await waitFor(() => expect(suggestions).toHaveBeenCalled())
    await userEvent.click(await screen.findByText(MILAN.label))

    expect(onUpdate).toHaveBeenCalledWith(
      ['is', 'city', [String(TOKYO.value), String(MILAN.value)]],
      expect.objectContaining({ [String(MILAN.value)]: MILAN.label })
    )

    // Regression guard: a mixed string/number clause list made the stats API
    // return a 500 and left the dropdown loading forever.
    const [, , newClauses] = onUpdate.mock.calls[0][0]
    expect(newClauses.every((c: unknown) => typeof c === 'string')).toBe(true)
  })

  test('a failing suggestions request surfaces an error instead of loading forever', async () => {
    mockAPI.get(
      suggestionsPath,
      async () =>
        ({
          status: 500,
          ok: false,
          json: async () => ({ error: 'internal server error' })
        }) as unknown as Response
    )

    renderRow()

    await userEvent.click(screen.getByPlaceholderText('Select a City'))

    expect(
      await screen.findByText(
        'Something went wrong when loading options. Please try again.'
      )
    ).toBeVisible()
    expect(screen.queryByText('Loading options...')).not.toBeInTheDocument()
  })
})
