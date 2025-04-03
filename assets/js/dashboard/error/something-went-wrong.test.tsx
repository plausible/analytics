import React from 'react'
import { render, screen } from '@testing-library/react'
import { GoToSites, SomethingWentWrongMessage } from './something-went-wrong'

it('handles unknown error', async () => {
  render(<SomethingWentWrongMessage error={1} />)

  expect(screen.getByText('Oops! Something went wrong.')).toBeVisible()
  expect(screen.getByText('Unknown error')).toBeVisible()
})

it('handles normal error', async () => {
  render(<SomethingWentWrongMessage error={new Error('any message')} />)

  expect(screen.getByText('Oops! Something went wrong.')).toBeVisible()
  expect(screen.getByText('Error: any message')).toBeVisible()
})

it('shows call to action if defined', async () => {
  render(<SomethingWentWrongMessage error={1} callToAction={<GoToSites />} />)

  expect(screen.getByText('Oops! Something went wrong.')).toBeVisible()
  expect(screen.getByText('Try going back or')).toBeVisible()
  expect(screen.getByRole('link', { name: 'go to your sites' })).toBeVisible()
})
