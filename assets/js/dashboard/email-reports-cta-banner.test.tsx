import React from 'react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../test-utils/app-context-providers'
import { MockAPI } from '../../test-utils/mock-api'
import { EmailReportsCTABanner } from './email-reports-cta-banner'

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
})

function renderBanner(showEmailReportsCta: boolean) {
  render(<EmailReportsCTABanner />, {
    wrapper: (props) => (
      <TestContextProviders
        siteOptions={{ domain, showEmailReportsCta }}
        {...props}
      />
    )
  })
}

test('renders nothing when showEmailReportsCta is false', () => {
  renderBanner(false)

  expect(screen.queryByRole('alert')).not.toBeInTheDocument()
})

test('renders the banner when showEmailReportsCta is true', () => {
  renderBanner(true)

  expect(screen.getByRole('alert')).toHaveTextContent(
    'Your first pageview has landed!'
  )
})

test('dismissing fires the mutation and hides the banner', async () => {
  const putHandler = mockAPI.put(`/api/${domain}/complete-onboarding`, {})

  renderBanner(true)

  await userEvent.click(screen.getByRole('button', { name: 'Dismiss' }))

  expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  await waitFor(() => expect(putHandler).toHaveBeenCalledTimes(1))
})

test('the email reports link points at the settings page with cta_clicked=true', async () => {
  renderBanner(true)

  const link = screen.getByRole('link', {
    name: /Get weekly traffic reports by email/
  })

  expect(link).toHaveAttribute(
    'href',
    `/${domain}/settings/email-reports?cta_clicked=true`
  )
})

test('still hides the banner (and does not throw) when the mutation fails', async () => {
  mockAPI.put(`/api/${domain}/complete-onboarding`, () =>
    Promise.resolve({
      ok: false,
      status: 401,
      json: async () => ({ error: 'unauthorized' })
    } as Response)
  )

  renderBanner(true)

  await userEvent.click(screen.getByRole('button', { name: 'Dismiss' }))

  expect(screen.queryByRole('alert')).not.toBeInTheDocument()
})
