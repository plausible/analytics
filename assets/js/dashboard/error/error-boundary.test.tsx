/** @format */

import React, { useState } from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import ErrorBoundary from './error-boundary'

const consoleErrorSpy = jest
  .spyOn(global.console, 'error')
  .mockImplementation(() => {})

const HappyPathUI = () => {
  const [count, setCount] = useState(0)
  if (count > 0) {
    throw new Error('Anything')
  }
  return (
    <button
      data-testid="happy-path-ui"
      onClick={() => {
        setCount(1)
      }}
    >
      Throw error
    </button>
  )
}

const ErrorUI = ({ error }: { error?: unknown }) => {
  return <div data-testid="error-ui">message: {(error as Error).message}</div>
}

it('shows only on error', async () => {
  render(
    <ErrorBoundary renderFallbackComponent={ErrorUI}>
      <HappyPathUI />
    </ErrorBoundary>
  )
  expect(screen.getByTestId('happy-path-ui')).toBeVisible()
  expect(screen.queryByTestId('error-ui')).toBeNull()

  await userEvent.click(screen.getByText('Throw error'))

  expect(screen.queryByTestId('happy-path-ui')).toBeNull()
  expect(screen.getByTestId('error-ui')).toBeVisible()

  expect(screen.getByText('message: Anything')).toBeVisible()

  expect(consoleErrorSpy.mock.calls).toEqual([
    [
      expect.objectContaining({
        detail: expect.objectContaining({ message: 'Anything' }),
        type: 'unhandled exception'
      })
    ],
    [
      expect.objectContaining({
        detail: expect.objectContaining({ message: 'Anything' }),
        type: 'unhandled exception'
      })
    ],
    [
      expect.stringMatching(
        'The above error occurred in the <HappyPathUI> component:'
      )
    ]
  ])
})
