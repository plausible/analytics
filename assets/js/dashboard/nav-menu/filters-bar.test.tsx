/** @format */

import React from 'react'
import { render, screen } from '../../../test-utils'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { FiltersBar, handleVisibility } from './filters-bar'
import { getRouterBasepath } from '../router'
import { stringifySearch } from '../util/url'

const domain = 'dummy.site'

beforeAll(() => {
  const mockResizeObserver = jest.fn(
    (handleEntries) =>
      ({
        observe: jest
          .fn()
          .mockImplementation((entry) =>
            handleEntries([entry], null as unknown as ResizeObserver)
          ),
        unobserve: jest.fn(),
        disconnect: jest.fn()
      }) as unknown as ResizeObserver
  )
  global.ResizeObserver = mockResizeObserver
})

test('user can see expected filters and clear them one by one or all together', async () => {
  const searchRecord = {
    filters: [
      ['is', 'country', ['DE']],
      ['is', 'goal', ['Subscribed to Newsletter']],
      ['is', 'page', ['/docs', '/blog']]
    ],
    labels: { DE: 'Germany' }
  }
  const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch(searchRecord)}`

  render(<FiltersBar />, {
    wrapper: (props) => (
      <TestContextProviders
        routerProps={{ initialEntries: [startUrl] }}
        siteOptions={{ domain }}
        {...props}
      />
    )
  })

  const queryFilterPills = () =>
    screen.queryAllByRole('link', { hidden: false, name: /.* is .*/i })

  // all filters appear in See more menu
  expect(queryFilterPills().map((m) => m.textContent)).toEqual([])

  await userEvent.click(
    screen.getByRole('button', {
      hidden: false,
      name: 'Show rest of the filters'
    })
  )

  expect(queryFilterPills().map((m) => m.textContent)).toEqual([
    'Country is Germany ',
    'Goal is Subscribed to Newsletter ',
    'Page is /docs or /blog '
  ])

  await userEvent.click(
    screen.getByRole('button', {
      hidden: false,
      name: 'Remove filter: Country is Germany'
    })
  )

  expect(queryFilterPills().map((m) => m.textContent)).toEqual([
    'Goal is Subscribed to Newsletter ',
    'Page is /docs or /blog '
  ])

  await userEvent.click(
    screen.getByRole('link', { hidden: false, name: 'Clear all filters' })
  )

  expect(queryFilterPills().map((m) => m.textContent)).toEqual([])
})

describe(`${handleVisibility.name}`, () => {
  it('is able to fit all exactly, whether "See more" is rendered in the actions or not', () => {
    const setVisibility = jest.fn()
    const input = {
      setVisibility,
      topBarWidth: 1000,
      actionsWidth: 100,
      seeMorePresent: false,
      seeMoreWidth: 50,
      pillWidths: [200, 200, 200, 200],
      pillGap: 25
    }
    handleVisibility(input)
    expect(setVisibility).toHaveBeenCalledTimes(1)
    expect(setVisibility).toHaveBeenLastCalledWith({
      width: 900,
      visibleCount: 4
    })

    handleVisibility({
      ...input,
      seeMorePresent: true,
      actionsWidth: input.actionsWidth + input.seeMoreWidth
    })
    expect(setVisibility).toHaveBeenCalledTimes(2)
    expect(setVisibility).toHaveBeenLastCalledWith({
      width: 900,
      visibleCount: 4
    })

    handleVisibility({ ...input, topBarWidth: 999 })
    expect(setVisibility).toHaveBeenCalledTimes(3)
    expect(setVisibility).toHaveBeenLastCalledWith({
      width: 675,
      visibleCount: 3
    })
  })

  it('can shrink to 0 width', () => {
    const setVisibility = jest.fn()
    const input = {
      setVisibility,
      topBarWidth: 300,
      actionsWidth: 100,
      seeMorePresent: true,
      seeMoreWidth: 50,
      pillWidths: [250],
      pillGap: 25
    }
    handleVisibility(input)
    expect(setVisibility).toHaveBeenCalledTimes(1)
    expect(setVisibility).toHaveBeenLastCalledWith({
      width: 0,
      visibleCount: 0
    })
  })
})
