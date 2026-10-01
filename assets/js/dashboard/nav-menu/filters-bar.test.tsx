import React, { ComponentProps } from 'react'
import { render, screen, waitFor, within } from '../../../test-utils'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { MockAPI } from '../../../test-utils/mock-api'
import { FiltersBar } from './filters-bar'
import { FilterEditorContextProvider } from '../filtering/filter-editor-context'
import {
  formatSegmentIdAsLabelKey,
  SavedSegment,
  SegmentData,
  SegmentType
} from '../filtering/segments'
import { Role, UserContextValue } from '../user-context'
import { getRouterBasepath } from '../router'
import { stringifySearch } from '../util/url-search-params'
import { mockAnimationsApi, mockResizeObserver } from 'jsdom-testing-mocks'

mockAnimationsApi()
mockResizeObserver()

const domain = 'dummy.site'

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

const suggestionsPath = (filterName: string) =>
  `/api/stats/${domain}/suggestions/${filterName}/`

const mockSuggestions = (filterName: string, values: string[]) =>
  mockAPI.get(
    suggestionsPath(filterName),
    values.map((value) => ({ value, label: value }))
  )

const getOptions = () =>
  within(screen.getByRole('listbox')).queryAllByRole('option')

const getOptionStates = () =>
  getOptions().map((option) => [
    option.textContent,
    option.getAttribute('aria-selected')
  ])

const getOption = (name: string) =>
  within(screen.getByRole('listbox')).getByRole('option', { name })

type SegmentWithData = SavedSegment & { segment_data: SegmentData }

const makeSegment = (
  overrides: Partial<
    Pick<SegmentWithData, 'name' | 'type' | 'segment_data'>
  > = {}
): SegmentWithData => ({
  id: 1,
  name: 'Mac users',
  type: SegmentType.personal,
  owner_id: 1,
  owner_name: 'Jane Smith',
  inserted_at: '2025-03-13T13:00:00',
  updated_at: '2025-03-13T13:00:00',
  segment_data: {
    filters: [['is', 'os', ['Mac']]],
    labels: {}
  },
  ...overrides
})

const getSegmentFilterSearch = (segment: SegmentWithData) => ({
  filters: [['is', 'segment', [segment.id]]],
  labels: { [formatSegmentIdAsLabelKey(segment.id)]: segment.name }
})

const getPillNames = () =>
  screen
    .queryAllByRole('group')
    .map((group) => group.getAttribute('aria-label'))

const renderFiltersBar = ({
  searchRecord,
  expandedSegment,
  siteOptions,
  ...providerProps
}: {
  searchRecord: Record<string, unknown>
  expandedSegment?: SegmentWithData
} & Omit<ComponentProps<typeof TestContextProviders>, 'children'>) =>
  render(
    <FilterEditorContextProvider>
      <FiltersBar />
    </FilterEditorContextProvider>,
    {
      wrapper: (props) => (
        <TestContextProviders
          routerProps={{
            initialEntries: [
              {
                pathname: getRouterBasepath({ domain, shared: false }),
                search: stringifySearch(searchRecord),
                state: expandedSegment ? { expandedSegment } : undefined
              }
            ]
          }}
          siteOptions={{ domain, ...siteOptions }}
          {...providerProps}
          {...props}
        />
      )
    }
  )

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

  expect(getPillNames()).toEqual([
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

  expect(getPillNames()).toEqual([
    'Goal is Subscribed to Newsletter',
    'Page is /docs or /blog'
  ])

  await userEvent.click(
    screen.getByRole('link', {
      hidden: false,
      name: 'Clear all filters'
    })
  )

  expect(getPillNames()).toEqual([])
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

test('the segment pill opens a menu with the segment details and actions', async () => {
  const segment = makeSegment({
    segment_data: {
      filters: [
        ['is', 'os', ['Mac']],
        ['is', 'country', ['DE']],
        ['is', 'source', ['Google']],
        ['is', 'page', ['/blog']]
      ],
      labels: { DE: 'Germany' }
    }
  })

  renderFiltersBar({
    searchRecord: getSegmentFilterSearch(segment),
    preloaded: { segments: [segment] }
  })

  expect(screen.getByRole('link', { name: 'Clear all filters' })).toBeVisible()
  expect(
    screen.queryByRole('link', { name: 'Save as segment' })
  ).not.toBeInTheDocument()

  await userEvent.click(
    screen.getByRole('button', { name: 'Open menu: Segment is Mac users' })
  )

  expect(screen.getByText('Created on 13 Mar by Jane Smith')).toBeVisible()
  expect(screen.queryByText('Country is')).not.toBeInTheDocument()

  await userEvent.click(screen.getByRole('button', { name: 'View filters' }))
  const filters = screen.getByRole('group', { name: 'View filters' })
  expect(filters).toHaveTextContent(
    [
      'Operating system is',
      'Mac',
      'Country is',
      'Germany',
      'Source is',
      'Google',
      'Page is',
      '/blog'
    ].join('')
  )

  expect(screen.getByRole('link', { name: 'Edit segment' })).toBeVisible()
  expect(
    screen.getByRole('button', { name: 'Duplicate segment' })
  ).toBeVisible()
  expect(screen.getByRole('button', { name: 'Delete segment' })).toBeVisible()

  await userEvent.click(screen.getByRole('link', { name: 'Edit segment' }))
  expect(screen.getByRole('button', { name: 'Save' })).toBeVisible()
  expect(screen.getByRole('group', { name: 'Page is /blog' })).toBeVisible()
})

const loggedInUser = (role: Role): UserContextValue => ({
  loggedIn: true,
  role,
  id: 1,
  team: { identifier: null, hasConsolidatedView: false }
})

const publicUser: UserContextValue = {
  loggedIn: false,
  role: Role.public,
  id: null,
  team: { identifier: null, hasConsolidatedView: false }
}

describe('segment pill menu actions depend on the user', () => {
  const segmentActions = ['Edit segment', 'Duplicate segment', 'Delete segment']

  it.each([
    {
      case: 'public user sees no actions and no author',
      user: publicUser,
      siteSegmentsAvailable: true,
      authorship: 'Created on 13 Mar',
      expectedActions: []
    },
    {
      case: 'viewer can only duplicate a site segment',
      user: loggedInUser(Role.viewer),
      siteSegmentsAvailable: true,
      authorship: 'Created on 13 Mar by Jane Smith',
      expectedActions: ['Duplicate segment']
    },
    {
      case: 'owner can edit a site segment even if site segments are not on the plan',
      user: loggedInUser(Role.owner),
      siteSegmentsAvailable: false,
      authorship: 'Created on 13 Mar by Jane Smith',
      expectedActions: segmentActions
    }
  ])(
    '$case',
    async ({ user, siteSegmentsAvailable, authorship, expectedActions }) => {
      const segment = makeSegment({ type: SegmentType.site })

      renderFiltersBar({
        searchRecord: getSegmentFilterSearch(segment),
        preloaded: { segments: [segment] },
        siteOptions: { siteSegmentsAvailable },
        user
      })

      await userEvent.click(
        screen.getByRole('button', { name: 'Open menu: Segment is Mac users' })
      )

      expect(screen.getByText(authorship)).toBeVisible()
      expect(
        segmentActions.filter((action) => screen.queryByText(action))
      ).toEqual(expectedActions)
    }
  )
})

test('the segment pill has no remove button when the dashboard is limited to the segment', () => {
  const segment = makeSegment({ type: SegmentType.site })

  renderFiltersBar({
    searchRecord: getSegmentFilterSearch(segment),
    preloaded: { segments: [segment] },
    limitedToSegment: segment,
    user: publicUser
  })

  expect(
    screen.getByRole('button', { name: 'Open menu: Segment is Mac users' })
  ).toBeVisible()
  expect(
    screen.queryByRole('button', {
      name: 'Remove filter: Segment is Mac users'
    })
  ).not.toBeInTheDocument()
})

test('a segment that is not found has a menu that explains it', async () => {
  const segment = makeSegment()

  renderFiltersBar({
    searchRecord: {
      filters: [
        ['is', 'segment', [segment.id]],
        ['is', 'page', ['/blog']]
      ],
      labels: getSegmentFilterSearch(segment).labels
    },
    preloaded: { segments: [] }
  })

  await userEvent.click(
    screen.getByRole('button', {
      name: 'Open menu: Segment is Mac users (Segment not found)'
    })
  )
  expect(screen.getByText('Segment not found')).toBeVisible()
  expect(
    screen.getByText(
      'It may have been deleted. Remove this filter to see your stats.'
    )
  ).toBeVisible()
})

test('shows Add filter, Save and Cancel in segment edit mode', async () => {
  const segment = makeSegment({
    name: 'Country, source, page',
    segment_data: {
      filters: [
        ['is', 'country', ['DE']],
        ['is', 'source', ['Google']],
        ['is', 'page', ['/blog']]
      ],
      labels: { DE: 'Germany' }
    }
  })

  renderFiltersBar({
    searchRecord: segment.segment_data,
    expandedSegment: segment,
    preloaded: { segments: [segment] }
  })

  expect(
    screen.getByRole('group', { name: 'Country is Germany' })
  ).toBeVisible()
  expect(screen.getByRole('button', { name: 'Add filter' })).toBeVisible()
  expect(screen.getByRole('button', { name: 'Save' })).toBeVisible()
  expect(screen.getByRole('link', { name: 'Cancel' })).toBeVisible()
  for (const action of ['Save as segment', 'Clear all filters']) {
    expect(screen.queryByRole('link', { name: action })).not.toBeInTheDocument()
  }
})

describe('inline filter editing', () => {
  test('the value list shows the selected values first and applies changes at once', async () => {
    mockSuggestions('source', ['Bing', 'Google', 'DuckDuckGo'])
    renderFiltersBar({
      searchRecord: { filters: [['is', 'source', ['Google']]] }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Edit filter: Source is Google' })
    )
    expect(screen.getByRole('combobox', { name: 'Values' })).toHaveFocus()

    await waitFor(() =>
      expect(getOptionStates()).toEqual([
        ['Google', 'true'],
        ['Bing', 'false'],
        ['DuckDuckGo', 'false']
      ])
    )

    await userEvent.click(getOption('Bing'))
    expect(getPillNames()).toEqual(['Source is Google or Bing'])
    expect(getOptionStates()).toEqual([
      ['Google', 'true'],
      ['Bing', 'true'],
      ['DuckDuckGo', 'false']
    ])
  })

  test('the value list supports the keyboard', async () => {
    mockSuggestions('source', ['Bing', 'Google'])
    renderFiltersBar({
      searchRecord: { filters: [['is', 'source', ['Google']]] }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Edit filter: Source is Google' })
    )
    await waitFor(() => expect(getOptions()).toHaveLength(2))

    await userEvent.keyboard('{ArrowDown}{Enter}')
    expect(getPillNames()).toEqual(['Source is Google or Bing'])

    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
    expect(
      screen.getByRole('button', {
        name: 'Edit filter: Source is Google or Bing'
      })
    ).toHaveFocus()
  })

  test('a filter without values is removed when the value list closes, and Escape does not clear the other filters', async () => {
    mockSuggestions('source', ['Google'])
    renderFiltersBar({
      searchRecord: {
        filters: [
          ['is', 'source', ['Google']],
          ['is', 'page', ['/blog']]
        ]
      }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Edit filter: Source is Google' })
    )
    await userEvent.click(getOption('Google'))
    expect(getPillNames()).toEqual(['Source is', 'Page is /blog'])

    await userEvent.keyboard('{Escape}')
    expect(getPillNames()).toEqual(['Page is /blog'])
  })

  test('Done closes the value list and focuses the pill', async () => {
    mockSuggestions('source', ['Bing', 'Google'])
    renderFiltersBar({
      searchRecord: { filters: [['is', 'source', ['Google']]] }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Edit filter: Source is Google' })
    )
    await userEvent.click(getOption('Bing'))
    await userEvent.click(screen.getByRole('button', { name: 'Done' }))

    expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
    expect(getPillNames()).toEqual(['Source is Google or Bing'])
    expect(
      screen.getByRole('button', {
        name: 'Edit filter: Source is Google or Bing'
      })
    ).toHaveFocus()
  })

  test('Deselect all clears the values, and Done then removes the filter', async () => {
    mockSuggestions('source', ['Bing', 'Google'])
    renderFiltersBar({
      searchRecord: {
        filters: [
          ['is', 'source', ['Google', 'Bing']],
          ['is', 'page', ['/blog']]
        ]
      }
    })

    await userEvent.click(
      screen.getByRole('button', {
        name: 'Edit filter: Source is Google or Bing'
      })
    )
    await userEvent.click(screen.getByRole('button', { name: 'Deselect all' }))

    expect(getPillNames()).toEqual(['Source is', 'Page is /blog'])
    expect(getOptionStates()).toEqual([
      ['Google', 'false'],
      ['Bing', 'false']
    ])
    expect(screen.getByRole('button', { name: 'Deselect all' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Done' }))
    expect(getPillNames()).toEqual(['Page is /blog'])
  })

  test('the operator can be changed', async () => {
    renderFiltersBar({
      searchRecord: { filters: [['is', 'source', ['Google']]] }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Change operator: Source is Google' })
    )
    const operators = screen.getByRole('group', { name: 'Operators' })
    expect(
      within(operators)
        .getAllByRole('button')
        .map((o) => o.textContent)
    ).toEqual(['is', 'is not', 'contains', 'does not contain'])

    await userEvent.click(
      within(operators).getByRole('button', { name: 'is not' })
    )
    expect(getPillNames()).toEqual(['Source is not Google'])
    expect(
      screen.queryByRole('group', { name: 'Operators' })
    ).not.toBeInTheDocument()
  })

  test('the operator is a button when the filter supports more than one operator', () => {
    renderFiltersBar({
      searchRecord: {
        filters: [['is', 'goal', ['Signup']]]
      }
    })
    expect(
      screen.getByRole('button', { name: 'Change operator: Goal is Signup' })
    ).toBeVisible()
  })

  test('the operator is not a button when the filter supports only one operator', () => {
    const segment = makeSegment()
    renderFiltersBar({
      searchRecord: getSegmentFilterSearch(segment),
      preloaded: { segments: [segment] }
    })
    expect(
      screen.queryByRole('button', {
        name: 'Change operator: Segment is Mac users'
      })
    ).not.toBeInTheDocument()
  })

  test('a contains filter takes typed values', async () => {
    renderFiltersBar({
      searchRecord: { filters: [['contains', 'page', ['/blog']]] }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Edit filter: Page contains /blog' })
    )
    expect(getOptionStates()).toEqual([['/blog', 'true']])

    await userEvent.keyboard('/docs')
    expect(getOptionStates()).toEqual([["Filter by '/docs'", 'false']])

    await userEvent.keyboard('{Enter}')
    expect(getPillNames()).toEqual(['Page contains /blog or /docs'])
    expect(getOptionStates()).toEqual([
      ['/blog', 'true'],
      ['/docs', 'true']
    ])
  })

  test('location values keep their labels', async () => {
    mockAPI.get(suggestionsPath('country'), [
      { value: 'DE', label: 'Germany' },
      { value: 'EE', label: 'Estonia' }
    ])
    renderFiltersBar({
      searchRecord: {
        filters: [['is', 'country', ['DE']]],
        labels: { DE: 'Germany' }
      }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Edit filter: Country is Germany' })
    )
    await waitFor(() => expect(getOptions()).toHaveLength(2))
    await userEvent.click(getOption('Estonia'))

    expect(getPillNames()).toEqual(['Country is Germany or Estonia'])
  })

  test('a new filter opens its value list, and goes away when closed without values', async () => {
    mockSuggestions('hostname', ['example.com'])
    renderFiltersBar({ searchRecord: {} })

    await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
    await userEvent.click(screen.getByRole('button', { name: 'Hostname' }))

    expect(getPillNames()).toEqual(['Hostname is'])
    await waitFor(() =>
      expect(screen.getByRole('combobox', { name: 'Values' })).toHaveFocus()
    )

    await userEvent.keyboard('{Escape}')
    expect(getPillNames()).toEqual([])
    expect(screen.getByRole('button', { name: 'Filter' })).toBeVisible()
  })

  test('a new filter is applied with its first value', async () => {
    mockSuggestions('hostname', ['example.com'])
    renderFiltersBar({
      searchRecord: { filters: [['is', 'page', ['/blog']]] }
    })

    await userEvent.click(screen.getByRole('button', { name: 'Add filter' }))
    await userEvent.click(screen.getByRole('button', { name: 'Hostname' }))
    expect(getPillNames()).toEqual(['Hostname is', 'Page is /blog'])

    await waitFor(() => expect(getOptions()).toHaveLength(1))
    await userEvent.click(getOption('example.com'))
    await userEvent.click(document.body)

    expect(getPillNames()).toEqual(['Hostname is example.com', 'Page is /blog'])
  })

  test('adding a dimension that already has a filter opens that filter', async () => {
    mockSuggestions('source', ['Google'])
    renderFiltersBar({
      searchRecord: { filters: [['is', 'source', ['Google']]] }
    })

    await userEvent.click(screen.getByRole('button', { name: 'Add filter' }))
    await userEvent.click(screen.getByRole('button', { name: 'Source' }))
    await userEvent.click(
      within(screen.getByTestId('filtermenu-submenu')).getByRole('button', {
        name: 'Source'
      })
    )

    expect(getPillNames()).toEqual(['Source is Google'])
    expect(
      screen.getByRole('button', { name: 'Edit filter: Source is Google' })
    ).toHaveAttribute('aria-expanded', 'true')
  })

  test('a goal can be added more than once', async () => {
    mockSuggestions('goal', ['Signup', 'Purchase'])
    renderFiltersBar({
      searchRecord: { filters: [['is', 'goal', ['Signup']]] }
    })

    await userEvent.click(screen.getByRole('button', { name: 'Add filter' }))
    await userEvent.click(screen.getByRole('button', { name: 'Goal' }))

    expect(getPillNames()).toEqual(['Goal is', 'Goal is Signup'])
  })

  test('a property is added from the property key list, where used keys are disabled', async () => {
    mockSuggestions('prop_key', ['author', 'logged_in'])
    mockAPI.get(
      `/api/stats/${domain}/suggestions/custom-prop-values/logged_in/`,
      [{ value: 'true', label: 'true' }]
    )
    renderFiltersBar({
      searchRecord: { filters: [['is', 'props:author', ['john']]] },
      siteOptions: { propsAvailable: true }
    })

    await userEvent.click(screen.getByRole('button', { name: 'Add filter' }))
    await userEvent.click(screen.getByRole('button', { name: 'Property' }))

    const keys = screen.getByRole('listbox', { name: 'Properties' })
    await waitFor(() =>
      expect(within(keys).getAllByRole('option')).toHaveLength(2)
    )
    expect(
      within(keys).getByRole('option', { name: 'author' })
    ).toHaveAttribute('aria-disabled', 'true')

    await userEvent.click(
      within(keys).getByRole('option', { name: 'logged_in' })
    )

    expect(getPillNames()).toEqual([
      "Property 'logged_in' is",
      "Property 'author' is john"
    ])
    expect(
      screen.getByRole('group', { name: "Property 'author' is john" })
    ).toHaveTextContent(/^authorisjohn$/)
    await waitFor(() => expect(getOptionStates()).toEqual([['true', 'false']]))
  })
})

describe('segment switch', () => {
  const segments = [
    makeSegment(),
    { ...makeSegment({ name: 'Windows users' }), id: 2 }
  ]

  test('the segment title opens a list of segments to switch to', async () => {
    renderFiltersBar({
      searchRecord: {
        filters: [
          ['is', 'segment', [1]],
          ['is', 'page', ['/blog']]
        ],
        labels: { [formatSegmentIdAsLabelKey(1)]: 'Mac users' }
      },
      preloaded: { segments }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Open menu: Segment is Mac users' })
    )
    await userEvent.click(screen.getByRole('button', { name: /^Mac users/ }))

    const list = screen.getByRole('group', { name: 'Switch segment' })
    expect(
      within(list).getByRole('link', { name: /Mac users/ })
    ).toHaveAttribute('aria-current', 'true')

    await userEvent.click(
      within(list).getByRole('link', { name: /Windows users/ })
    )
    expect(getPillNames()).toEqual([
      'Segment is Windows users',
      'Page is /blog'
    ])
  })

  test('the segment title is static when there is no other segment', async () => {
    renderFiltersBar({
      searchRecord: getSegmentFilterSearch(segments[0]),
      preloaded: { segments: [segments[0]] }
    })

    await userEvent.click(
      screen.getByRole('button', { name: 'Open menu: Segment is Mac users' })
    )
    expect(screen.getByTitle('Mac users')).toBeVisible()
    expect(
      screen.queryByRole('button', { name: /^Mac users/ })
    ).not.toBeInTheDocument()
  })
})
