import React, { ComponentProps } from 'react'
import { render, screen } from '../../../test-utils'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { FiltersBar } from './filters-bar'
import { getRouterBasepath } from '../router'
import { stringifySearch } from '../util/url-search-params'
import { mockAnimationsApi, mockResizeObserver } from 'jsdom-testing-mocks'

mockAnimationsApi()
mockResizeObserver()

const domain = 'dummy.site'

const renderFiltersBar = ({
  searchRecord,
  siteOptions,
  ...providerProps
}: {
  searchRecord: Record<string, unknown>
} & Omit<ComponentProps<typeof TestContextProviders>, 'children'>) =>
  render(<FiltersBar />, {
    wrapper: (props) => (
      <TestContextProviders
        routerProps={{
          initialEntries: [
            {
              pathname: getRouterBasepath({ domain, shared: false }),
              search: stringifySearch(searchRecord)
            }
          ]
        }}
        siteOptions={{ domain, ...siteOptions }}
        {...providerProps}
        {...props}
      />
    )
  })

test('user can see expected filters and clear them one by one or all together', async () => {
  renderFiltersBar({
    searchRecord: {
      filters: [
        ['is', 'country', ['DE']],
        ['is', 'goal', ['Subscribed to Newsletter']],
        ['is', 'page', ['/docs', '/blog']]
      ],
      labels: { DE: 'Germany' }
    }
  })

  const queryFilterPills = () =>
    screen.queryAllByRole('link', { hidden: false, name: /.* is .*/i })

  expect(queryFilterPills().map((m) => m.textContent)).toEqual([
    'Country is Germany',
    'Goal is Subscribed to Newsletter',
    'Page is /docs or /blog'
  ])

  await userEvent.click(
    screen.getByRole('button', {
      hidden: false,
      name: 'Remove filter: Country is Germany'
    })
  )

  expect(queryFilterPills().map((m) => m.textContent)).toEqual([
    'Goal is Subscribed to Newsletter',
    'Page is /docs or /blog'
  ])

  await userEvent.click(
    screen.getByRole('link', {
      hidden: false,
      name: 'Clear all filters'
    })
  )

  expect(queryFilterPills().map((m) => m.textContent)).toEqual([])
})

test('action tooltips show the keybind and the docs link', async () => {
  renderFiltersBar({
    searchRecord: {
      filters: [['is', 'country', ['DE']]],
      labels: { DE: 'Germany' }
    }
  })

  const addFilter = screen.getByRole('button', { name: 'Add filter' })
  await userEvent.hover(addFilter)
  expect(screen.getByRole('tooltip')).toHaveTextContent('Add filter')
  await userEvent.unhover(addFilter)

  const clearAll = screen.getByRole('link', { name: 'Clear all filters' })
  await userEvent.hover(clearAll)
  expect(screen.getByRole('tooltip')).toHaveTextContent('Clear all filtersESC')
  await userEvent.unhover(clearAll)

  await userEvent.hover(screen.getByRole('link', { name: 'Save as segment' }))
  await userEvent.hover(
    screen.getByRole('link', { name: 'Learn more about segments' })
  )
  expect(
    screen.getByRole('link', { name: 'Learn more about segments' })
  ).toHaveAttribute(
    'href',
    'https://plausible.io/docs/filters-segments#how-to-save-a-segment'
  )
})
