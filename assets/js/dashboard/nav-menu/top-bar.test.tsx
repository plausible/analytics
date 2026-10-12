import React from 'react'
import {
  render,
  screen,
  waitFor,
  fireEvent,
  waitForElementToBeRemoved,
  within
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { TopBar } from './top-bar'
import { MockAPI } from '../../../test-utils/mock-api'
import {
  mockAnimationsApi,
  mockResizeObserver,
  mockIntersectionObserver,
  mockViewportForTestGroup
} from 'jsdom-testing-mocks'
import { SavedSegment, SegmentData, SegmentType } from '../filtering/segments'
import { getRouterBasepath } from '../router'
import { stringifySearch } from '../util/url-search-params'

mockAnimationsApi()
mockResizeObserver()
mockIntersectionObserver()

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
  mockAPI.get('/api/sites', { data: [{ domain }] })
})

test('user can open and close site switcher', async () => {
  mockAPI.get('/api/sites', {
    data: [domain, 'example.com', 'blog.example.com', 'aççented.ca'].map(
      (domain) => ({
        domain
      })
    )
  })

  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  const toggleSiteSwitcher = screen.getByRole('button', { name: domain })
  await userEvent.click(toggleSiteSwitcher)
  expect(
    screen
      .queryAllByRole('link')
      .map((el) => ({ text: el.textContent, href: el.getAttribute('href') }))
  ).toEqual(
    [
      { text: ['Back to sites'], href: '/sites' },
      { text: ['Site settings'], href: `/${domain}/settings/general` },
      { text: ['dummy.site', '1'], href: '#' },
      { text: ['example.com', '2'], href: `/example.com` },
      { text: ['blog.example.com', '3'], href: `/blog.example.com` },
      { text: ['aççented.ca', '4'], href: `/a%C3%A7%C3%A7ented.ca` }
    ].map((l) => ({ ...l, text: l.text.join('') }))
  )

  expect(screen.queryByTestId('sitemenu')).toBeInTheDocument()
  await userEvent.click(toggleSiteSwitcher)
  expect(screen.queryByTestId('sitemenu')).not.toBeInTheDocument()
  expect(screen.queryAllByRole('menuitem')).toEqual([])
})

test('site switcher links to a site needing verification with verify_installation and flow params', async () => {
  mockAPI.get('/api/sites', {
    data: [
      { domain, needs_verification: false },
      { domain: 'example.com', needs_verification: true }
    ]
  })

  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  const toggleSiteSwitcher = screen.getByRole('button', { name: domain })
  await userEvent.click(toggleSiteSwitcher)

  expect(screen.getByRole('link', { name: /example\.com/ })).toHaveAttribute(
    'href',
    '/example.com?verify_installation=true&flow=provisioning'
  )
})

test('user can open and close filters dropdown', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  const toggleFilters = screen.getByRole('button', { name: 'Filter' })
  await userEvent.click(toggleFilters)

  expect(
    Array.from(
      screen.getByTestId('filtermenu').querySelectorAll('a, button')
    ).map((el) => el.textContent)
  ).toEqual([
    'Page',
    'Hostname',
    'Source',
    'UTM tags',
    'Location',
    'Screen size',
    'Browser',
    'Operating system',
    'Goal'
  ])

  // rows without a submenu link straight to their dimension
  expect(screen.getByRole('link', { name: 'Hostname' })).toHaveAttribute(
    'href',
    `/${domain}/filter/hostname`
  )
  expect(screen.queryByRole('link', { name: 'Page' })).not.toBeInTheDocument()

  await userEvent.click(toggleFilters)
  expect(screen.queryByTestId('filtermenu')).not.toBeInTheDocument()
  expect(screen.queryAllByRole('link')).toEqual([])
})

test.each([
  [
    'Page',
    [
      ['Page', 'page'],
      ['Entry page', 'entry_page'],
      ['Exit page', 'exit_page']
    ]
  ],
  [
    'Browser',
    [
      ['Browser', 'browser'],
      ['Browser version', 'browser_version']
    ]
  ],
  [
    'Location',
    [
      ['Country', 'country'],
      ['Region', 'region'],
      ['City', 'city']
    ]
  ]
])('user can open the %s submenu', async (rowName, expectedItems) => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  const row = screen.getByRole('button', { name: rowName })
  expect(row).toHaveAttribute('aria-expanded', 'false')

  await userEvent.click(row)
  expect(row).toHaveAttribute('aria-expanded', 'true')

  const submenu = screen.getByTestId('filtermenu-submenu')
  expect(
    Array.from(submenu.querySelectorAll('a')).map((el) => [
      el.textContent,
      el.getAttribute('href')
    ])
  ).toEqual(
    expectedItems.map(([label, dimension]) => [
      label,
      `/${domain}/filter/${dimension}`
    ])
  )
})

test('user can walk the filter menu and a submenu with Tab', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))

  await userEvent.tab()
  const pageRow = screen.getByRole('button', { name: 'Page' })
  expect(pageRow).toHaveFocus()
  expect(pageRow).toHaveAttribute('aria-expanded', 'true')

  const submenuLinks = Array.from(
    screen.getByTestId('filtermenu-submenu').querySelectorAll('a')
  )
  await userEvent.tab()
  expect(submenuLinks[0]).toHaveFocus()
  await userEvent.tab()
  expect(submenuLinks[1]).toHaveFocus()
  await userEvent.tab({ shift: true })
  expect(submenuLinks[0]).toHaveFocus()

  await userEvent.keyboard('{Escape}')
  expect(pageRow).toHaveFocus()
  await waitFor(() => {
    expect(screen.queryByTestId('filtermenu-submenu')).not.toBeInTheDocument()
  })
  expect(screen.getByTestId('filtermenu')).toBeInTheDocument()
})

test('property row only shows when props are available', async () => {
  const { unmount } = render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })
  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  expect(
    screen.queryByRole('link', { name: 'Property' })
  ).not.toBeInTheDocument()
  unmount()

  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders
        siteOptions={{ domain, propsAvailable: true }}
        {...props}
      />
    )
  })
  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  expect(screen.getByRole('link', { name: 'Property' })).toHaveAttribute(
    'href',
    `/${domain}/filter/props`
  )
})

test('segment row only shows when listable segments exist, and lists them in its submenu', async () => {
  const segment = {
    id: 7,
    name: 'My people',
    type: SegmentType.personal,
    owner_id: 1,
    owner_name: 'Test User',
    inserted_at: '2025-02-26T10:00:00',
    updated_at: '2025-02-26T10:00:00',
    segment_data: { filters: [], labels: {} }
  }

  const { unmount } = render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })
  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  expect(
    screen.queryByRole('button', { name: 'Segment' })
  ).not.toBeInTheDocument()
  unmount()

  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders
        siteOptions={{ domain }}
        preloaded={{ segments: [segment] }}
        {...props}
      />
    )
  })
  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  await userEvent.click(screen.getByRole('button', { name: 'Segment' }))

  const submenu = screen.getByTestId('filtermenu-submenu')
  expect(submenu.querySelectorAll('a')).toHaveLength(1)
  expect(within(submenu).getByTitle(segment.name)).toBeVisible()
  // Without shared segments, the authorship would say the same on every row.
  expect(within(submenu).getByText('26 Feb')).toBeVisible()
  expect(within(submenu).queryByText('Personal segment')).toBeNull()
})

test('segment rows show authorship and the edited date when shared segments are available', async () => {
  const segments = [
    {
      id: 7,
      name: 'My people',
      type: SegmentType.personal,
      owner_id: 1,
      owner_name: 'Test User',
      inserted_at: '2025-02-26T10:00:00',
      updated_at: '2025-02-26T10:00:00',
      segment_data: { filters: [], labels: {} }
    },
    {
      id: 8,
      name: 'APAC region',
      type: SegmentType.site,
      owner_id: 2,
      owner_name: 'Jane Smith',
      inserted_at: '2025-02-26T10:00:00',
      updated_at: '2025-03-13T16:00:00',
      segment_data: { filters: [], labels: {} }
    }
  ]

  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders
        siteOptions={{ domain, siteSegmentsAvailable: true }}
        preloaded={{ segments }}
        {...props}
      />
    )
  })
  await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  await userEvent.click(screen.getByRole('button', { name: 'Segment' }))

  const submenu = screen.getByTestId('filtermenu-submenu')
  expect(within(submenu).getByText('Personal segment')).toBeVisible()
  expect(within(submenu).getByText('• 26 Feb')).toBeVisible()
  expect(within(submenu).getByText('Jane Smith')).toBeVisible()
  expect(within(submenu).getByText('• Edited 13 Mar')).toBeVisible()
})

test.each([
  { segmentCount: 6, expectSearch: false, expectedShowMoreRow: null },
  { segmentCount: 7, expectSearch: true, expectedShowMoreRow: 'Show 1 more' }
])(
  'the segment submenu shows a search box and a show-more row for $segmentCount segments: $expectSearch',
  async ({ segmentCount, expectSearch, expectedShowMoreRow }) => {
    const segments = Array.from({ length: segmentCount }, (_, index) => ({
      id: index + 1,
      name: `Segment ${index + 1}`,
      type: SegmentType.personal,
      owner_id: 1,
      owner_name: 'Test User',
      inserted_at: '2025-02-26T10:00:00',
      updated_at: '2025-02-26T10:00:00',
      segment_data: { filters: [], labels: {} }
    }))

    render(<TopBar showCurrentVisitors={false} />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain }}
          preloaded={{ segments }}
          {...props}
        />
      )
    })
    await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
    await userEvent.click(screen.getByRole('button', { name: 'Segment' }))

    const submenu = screen.getByTestId('filtermenu-submenu')
    expect(!!within(submenu).queryByTestId('search-input')).toBe(expectSearch)
    expect(
      within(submenu).queryByText(/Show \d+ more/)?.textContent ?? null
    ).toBe(expectedShowMoreRow)
    expect(submenu.querySelectorAll('a')).toHaveLength(
      Math.min(segmentCount, 6)
    )
  }
)

describe('segment edit mode', () => {
  const segment: SavedSegment & { segment_data: SegmentData } = {
    id: 1,
    name: 'Blog',
    type: SegmentType.personal,
    owner_id: 1,
    owner_name: 'Test User',
    inserted_at: '2025-02-26T10:00:00',
    updated_at: '2025-02-26T10:00:00',
    segment_data: {
      filters: [['is', 'page', ['/blog']]],
      labels: {}
    }
  }

  const renderTopBarWithSegmentFilters = ({ editing }: { editing: boolean }) =>
    render(<TopBar showCurrentVisitors={false} />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain }}
          preloaded={{ segments: [segment] }}
          routerProps={{
            initialEntries: [
              {
                pathname: getRouterBasepath({ domain, shared: false }),
                search: stringifySearch(segment.segment_data),
                state: editing ? { expandedSegment: segment } : undefined
              }
            ]
          }}
          {...props}
        />
      )
    })

  const querySiteControls = () => [
    screen.queryByRole('button', { name: domain }),
    screen.queryByTestId('query-period-picker'),
    screen.queryByTestId('dashboard-options-menu')
  ]

  test('shows the site switcher, period picker and options menu outside edit mode', () => {
    renderTopBarWithSegmentFilters({ editing: false })

    for (const control of querySiteControls()) {
      expect(control).toBeInTheDocument()
    }
  })

  test('hides the site switcher, period picker and options menu in edit mode', () => {
    renderTopBarWithSegmentFilters({ editing: true })

    for (const control of querySiteControls()) {
      expect(control).not.toBeInTheDocument()
    }
  })
})

describe('narrow viewport (no room for a submenu beside the menu)', () => {
  mockViewportForTestGroup({ width: '500px', height: '800px' })

  const openFilterMenu = async () => {
    render(<TopBar showCurrentVisitors={false} />, {
      wrapper: (props) => (
        <TestContextProviders siteOptions={{ domain }} {...props} />
      )
    })
    await userEvent.click(screen.getByRole('button', { name: 'Filter' }))
  }

  test('a submenu row drills down in place, and the back button returns', async () => {
    await openFilterMenu()
    await userEvent.click(screen.getByRole('button', { name: 'Page' }))

    const submenu = screen.getByTestId('filtermenu-submenu')
    expect(
      Array.from(submenu.querySelectorAll('a')).map((el) => el.textContent)
    ).toEqual(['Page', 'Entry page', 'Exit page'])

    // The main list is replaced, not shown beside the submenu.
    expect(
      screen.queryByRole('link', { name: 'Hostname' })
    ).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Page' }))

    expect(screen.queryByTestId('filtermenu-submenu')).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Hostname' })).toBeInTheDocument()
  })

  test('tabbing onto a submenu row does not drill down', async () => {
    await openFilterMenu()

    await userEvent.tab()

    const pageRow = screen.getByRole('button', { name: 'Page' })
    expect(pageRow).toHaveFocus()
    expect(pageRow).toHaveAttribute('aria-expanded', 'false')
    expect(screen.queryByTestId('filtermenu-submenu')).not.toBeInTheDocument()
  })
})

test('current visitors renders when visitors are present and disappears after visitors are null', async () => {
  mockAPI.get(`/api/stats/${domain}/current-visitors`, 500)
  render(<TopBar showCurrentVisitors={true} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await waitFor(() => {
    expect(
      screen.queryByRole('link', { name: /500 current visitors/ })
    ).toBeVisible()
  })

  mockAPI.get(`/api/stats/${domain}/current-visitors`, null)
  fireEvent(document, new CustomEvent('tick'))
  await waitForElementToBeRemoved(() =>
    screen.queryByRole('link', { name: /current visitors/ })
  )
})
