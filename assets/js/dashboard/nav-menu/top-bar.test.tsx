import React from 'react'
import {
  act,
  render,
  screen,
  waitFor,
  fireEvent,
  waitForElementToBeRemoved
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { TopBar, fadeAt, liftAt } from './top-bar'
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

/** The scroll offset at which the stand-in header loses the site name. */
const HEADER_SITE_NAME_BOTTOM_PX = 40

const placeHeaderSiteName = () => {
  const chip = document.createElement('div')
  chip.id = 'nav-site'
  jest
    .spyOn(chip, 'getBoundingClientRect')
    .mockReturnValue({ bottom: HEADER_SITE_NAME_BOTTOM_PX } as DOMRect)
  document.body.appendChild(chip)
}

const removeHeaderSiteName = () => {
  document.getElementById('nav-site')?.remove()
}

const scrollTo = async (offset: number) => {
  Object.defineProperty(window, 'scrollY', {
    value: offset,
    configurable: true
  })

  await act(async () => {
    fireEvent.scroll(window)
    await new Promise(requestAnimationFrame)
  })
}

/** Carries the fade the scroll handler writes. */
const bar = () =>
  document.getElementById('stats-container-top')!
    .nextElementSibling as HTMLElement

let mockAPI: MockAPI

beforeAll(() => {
  mockAPI = new MockAPI().start()
})

afterAll(() => {
  mockAPI.stop()
})

beforeEach(() => {
  mockAPI.clear()
  placeHeaderSiteName()
})

afterEach(() => {
  removeHeaderSiteName()
  Object.defineProperty(window, 'scrollY', { value: 0, configurable: true })
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
    'Operating system',
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

test('the bar holds at nothing for a stretch in the middle of the hand-over', () => {
  expect(fadeAt(0)).toBe(1)
  expect(fadeAt(0.225)).toBeCloseTo(0.5)
  expect(fadeAt(0.45)).toBe(0)
  expect(fadeAt(0.5)).toBe(0)
  expect(fadeAt(0.725)).toBeCloseTo(0.5)
  expect(fadeAt(0.9)).toBe(1)
  expect(fadeAt(1)).toBe(1)
})

test('the contents leaving the bar lift away and the ones replacing them rise in', () => {
  expect(liftAt(0)).toBeCloseTo(0)
  expect(liftAt(0.225)).toBeLessThan(0)
  expect(liftAt(0.725)).toBeGreaterThan(0)
  expect(liftAt(0.9)).toBeCloseTo(0)
})

test('site label arrives before the header stops naming the site', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  expect(screen.queryByTestId('site-switcher-static')).not.toBeInTheDocument()

  // Short of the swap, so the bar still holds the contents it had.
  await scrollTo(HEADER_SITE_NAME_BOTTOM_PX * 0.3)
  expect(screen.queryByTestId('site-switcher-static')).not.toBeInTheDocument()

  // Past the swap, and the header has not lost the name yet.
  await scrollTo(HEADER_SITE_NAME_BOTTOM_PX * 0.6)
  expect(await screen.findByTestId('site-switcher-static')).toBeVisible()

  await scrollTo(0)
  await waitFor(() => {
    expect(screen.queryByTestId('site-switcher-static')).not.toBeInTheDocument()
  })
})

test('the bar is written empty across the middle of the hand-over', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  expect(bar().style.getPropertyValue('--bar-fade')).toBe('1.000')

  await scrollTo(HEADER_SITE_NAME_BOTTOM_PX / 2)
  expect(bar().style.getPropertyValue('--bar-fade')).toBe('0.000')

  await scrollTo(HEADER_SITE_NAME_BOTTOM_PX)
  expect(bar().style.getPropertyValue('--bar-fade')).toBe('1.000')
})

test('site label stays put when nothing in the header names the site', () => {
  removeHeaderSiteName()

  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  expect(screen.getByTestId('site-switcher-static')).toBeVisible()
})

test('site label shows without scrolling where no app header names the site', async () => {
  render(<TopBar showCurrentVisitors={false} />, {
    wrapper: (props) => (
      <TestContextProviders
        siteOptions={{ domain, embedded: true }}
        {...props}
      />
    )
  })

  expect(screen.getByTestId('site-switcher-static')).toBeVisible()
})
