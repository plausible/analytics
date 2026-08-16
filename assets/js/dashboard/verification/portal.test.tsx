import React from 'react'
import { act, render, screen } from '@testing-library/react'
import { useLocation } from 'react-router-dom'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import {
  VERIFICATION_FINISHED_EVENT,
  VerificationLiveViewPortal
} from './portal'

function LocationDisplay() {
  const location = useLocation()
  return <div data-testid="location">{location.pathname + location.search}</div>
}

function renderWithInitialEntry(initialEntry: string) {
  render(
    <>
      <VerificationLiveViewPortal />
      <LocationDisplay />
    </>,
    {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain: 'some-domain' }}
          routerProps={{ initialEntries: [initialEntry] }}
          {...props}
        />
      )
    }
  )
}

function dispatchVerificationFinished(queryParams: string[]) {
  act(() => {
    window.dispatchEvent(
      new CustomEvent(VERIFICATION_FINISHED_EVENT, {
        detail: { queryParams }
      })
    )
  })
}

test('drops exactly the query params named in the event detail, leaving every other param untouched', () => {
  renderWithInitialEntry(
    '/some-domain?f=contains,os,a&f=contains,page,/&verify_installation=true&flow=provisioning&comparison=year_over_year'
  )

  dispatchVerificationFinished(['verify_installation', 'flow'])

  expect(screen.getByTestId('location').textContent).toBe(
    '/?f=contains,os,a&f=contains,page,/&comparison=year_over_year'
  )
})

test('does nothing when none of the named params are present', () => {
  renderWithInitialEntry('/some-domain?comparison=year_over_year')

  dispatchVerificationFinished(['verify_installation', 'flow'])

  expect(screen.getByTestId('location').textContent).toBe(
    '/?comparison=year_over_year'
  )
})

test('drops only verify_installation, keeping a real param that happens to be a prefix of it', () => {
  renderWithInitialEntry(
    '/some-domain?verify_installation=true&verify_installation_extra=keep-me'
  )

  dispatchVerificationFinished(['verify_installation'])

  expect(screen.getByTestId('location').textContent).toBe(
    '/?verify_installation_extra=keep-me'
  )
})
