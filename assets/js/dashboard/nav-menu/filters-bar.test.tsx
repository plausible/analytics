import React, { ComponentProps } from 'react'
import { render, screen } from '../../../test-utils'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { FiltersBar } from './filters-bar'
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

const renderFiltersBar = ({
  searchRecord,
  expandedSegment,
  siteOptions,
  ...providerProps
}: {
  searchRecord: Record<string, unknown>
  expandedSegment?: SegmentWithData
} & Omit<ComponentProps<typeof TestContextProviders>, 'children'>) =>
  render(<FiltersBar />, {
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
    screen.getByRole('button', { name: 'Segment is Mac users' })
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
  expect(
    screen.getByRole('link', { hidden: false, name: 'Page is /blog' })
  ).toBeVisible()
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
        screen.getByRole('button', { name: 'Segment is Mac users' })
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
    screen.getByRole('button', { name: 'Segment is Mac users' })
  ).toBeVisible()
  expect(
    screen.queryByRole('button', {
      name: 'Remove filter: Segment is Mac users'
    })
  ).not.toBeInTheDocument()
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
    screen.getByRole('link', { hidden: false, name: 'Country is Germany' })
  ).toBeVisible()
  expect(screen.getByRole('button', { name: 'Add filter' })).toBeVisible()
  expect(screen.getByRole('button', { name: 'Save' })).toBeVisible()
  expect(screen.getByRole('link', { name: 'Cancel' })).toBeVisible()
  for (const action of ['Save as segment', 'Clear all filters']) {
    expect(screen.queryByRole('link', { name: action })).not.toBeInTheDocument()
  }
})
