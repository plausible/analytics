import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { SmoothingPicker, useStoredSmoothing } from './smoothing-picker'

function Picker({ domain }: { domain: string }) {
  return <SmoothingPicker {...useStoredSmoothing(domain)} />
}

test('defaults to none and remembers smoothing per site, including disabling it', async () => {
  const { rerender, unmount } = render(<Picker domain="example.com" />)
  expect(screen.getByRole('button', { name: 'None' })).toHaveAttribute(
    'aria-pressed',
    'true'
  )

  await userEvent.click(screen.getByRole('button', { name: '7-period MA' }))
  expect(screen.getByRole('button', { name: '7-period MA' })).toHaveAttribute(
    'aria-pressed',
    'true'
  )
  expect(localStorage.getItem('graphSmoothing__example.com')).toBe('7')

  rerender(<Picker domain="other.com" />)
  expect(screen.getByRole('button', { name: 'None' })).toHaveAttribute(
    'aria-pressed',
    'true'
  )
  await userEvent.click(screen.getByRole('button', { name: '30-period MA' }))
  expect(localStorage.getItem('graphSmoothing__other.com')).toBe('30')

  rerender(<Picker domain="example.com" />)
  expect(screen.getByRole('button', { name: '7-period MA' })).toHaveAttribute(
    'aria-pressed',
    'true'
  )
  unmount()
  render(<Picker domain="other.com" />)
  expect(screen.getByRole('button', { name: '30-period MA' })).toHaveAttribute(
    'aria-pressed',
    'true'
  )

  await userEvent.click(screen.getByRole('button', { name: 'None' }))
  expect(localStorage.getItem('graphSmoothing__other.com')).toBe('none')
})

test('ignores invalid stored smoothing', () => {
  localStorage.setItem('graphSmoothing__example.com', 'invalid')
  render(<Picker domain="example.com" />)
  expect(screen.getByRole('button', { name: 'None' })).toHaveAttribute(
    'aria-pressed',
    'true'
  )
})
