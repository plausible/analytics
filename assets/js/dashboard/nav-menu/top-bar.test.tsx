/** @format */

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

const domain = 'dummy.site'
const domains = [domain, 'example.com', 'blog.example.com']

let mockAPI: MockAPI

beforeAll(() => {
  global.IntersectionObserver = jest.fn(
    () =>
      ({
        observe: jest.fn(),
        unobserve: jest.fn(),
        disconnect: jest.fn()
      }) as unknown as IntersectionObserver
  )
  mockAPI = new MockAPI().start()
})

afterAll(() => {
  mockAPI.stop()
})

beforeEach(() => {
  mockAPI.clear()
  mockAPI.get('/api/sites', { data: domains.map((domain) => ({ domain })) })
})

test('user can open and close site switcher', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  const toggleSiteSwitcher = screen.getByRole('button', { name: domain })
  await userEvent.click(toggleSiteSwitcher)
  expect(screen.queryAllByRole('link').map((el) => el.textContent)).toEqual(
    [
      ['example.com', '2'],
      ['blog.example.com', '3']
    ].map((a) => a.join(''))
  )
  expect(screen.queryAllByRole('menuitem').map((el) => el.textContent)).toEqual(
    ['Site Settings', 'View All']
  )
  await userEvent.click(toggleSiteSwitcher)
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
    'Source',
    'Location',
    'Screen size',
    'Browser',
    'Operating System',
    'UTM tags',
    'Goal',
    'Hostname',
    'Segment'
  ])
  await userEvent.click(toggleFilters)
  expect(screen.queryAllByRole('link')).toEqual([])
})

test('current visitors renders when visitors are present and disappears after visitors are null', async () => {
  mockAPI.get(`/api/stats/${domain}/current-visitors?`, 500)
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

  mockAPI.get(`/api/stats/${domain}/current-visitors?`, null)
  fireEvent(document, new CustomEvent('tick'))
  await waitForElementToBeRemoved(() =>
    screen.queryByRole('link', { name: /current visitors/ })
  )
})
