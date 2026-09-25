import React from 'react'
import { render, screen, act, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { showToast, ToastHost } from './toast'

test('shows a success toast and hides it after close', async () => {
  render(<ToastHost />)

  act(() => {
    showToast({ message: 'Segment created' })
  })

  await waitFor(() => {
    expect(screen.getByText('Success!')).toBeVisible()
  })
  expect(screen.getByText('Segment created')).toBeVisible()

  await userEvent.click(screen.getByRole('button', { name: 'Close toast' }))

  await waitFor(() => {
    expect(screen.queryByText('Segment created')).toBeNull()
  })
})
