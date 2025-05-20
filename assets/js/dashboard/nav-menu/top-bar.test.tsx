import React from 'react'
import {
  render,
  screen,
  waitFor,
  fireEvent,
  waitForElementToBeRemoved
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { TopBar } from './top-bar'
import { MockAPI } from '../../../test-utils/mock-api'
import {
  mockAnimationsApi,
  mockResizeObserver,
  mockIntersectionObserver
} from 'jsdom-testing-mocks'

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
      { text: ['Site settings'], href: `/${domain}/settings/general` },
      { text: ['dummy.site', '1'], href: '#' },
      { text: ['example.com', '2'], href: `/example.com` },
      { text: ['blog.example.com', '3'], href: `/blog.example.com` },
      { text: ['aççented.ca', '4'], href: `/a%C3%A7%C3%A7ented.ca` },
      { text: ['View all'], href: '/sites' }
    ].map((l) => ({ ...l, text: l.text.join('') }))
  )

  expect(screen.queryByTestId('sitemenu')).toBeInTheDocument()
  await userEvent.click(toggleSiteSwitcher)
  expect(screen.queryByTestId('sitemenu')).not.toBeInTheDocument()
  expect(screen.queryAllByRole('menuitem')).toEqual([])
})

test('user can open and close filters dropdown', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  const toggleFilters = screen.getByRole('button', { name: 'Filter' })
  await userEvent.click(toggleFilters)
  expect(screen.queryAllByRole('link').map((el) => el.textContent)).toEqual([
    'Page',
    'Hostname',
    'Source',
    'UTM tags',
    'Location',
    'Screen size',
    'Browser',
    'Operating System',
    'Goal'
  ])
  await userEvent.click(toggleFilters)
  expect(screen.queryByTestId('filtermenu')).not.toBeInTheDocument()
  expect(screen.queryAllByRole('link')).toEqual([])
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
