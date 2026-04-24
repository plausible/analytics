import React, { useState, Dispatch, SetStateAction } from 'react'
import { act, render, screen } from '@testing-library/react'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import GoogleKeywordsModal from './google-keywords'
import { MockAPI } from '../../../../test-utils/mock-api'

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

beforeEach(() => {
  const modalRoot = document.createElement('div')
  modalRoot.setAttribute('id', 'modal_root')
  document.body.appendChild(modalRoot)
})

afterEach(() => {
  document.getElementById('modal_root')?.remove()
})

describe('GoogleKeywordsModal', () => {
  test('opening the modal for a second time with the same dashboardState gets response from cache', async () => {
    const googleKeywordsHandler = mockAPI.get(
      `/api/stats/${domain}/referrers/Google/`,
      { results: [] }
    )

    let setOpen: Dispatch<SetStateAction<boolean>>

    function ToggleableModal() {
      const [open, s] = useState(false)
      setOpen = s
      return open ? <GoogleKeywordsModal /> : null
    }

    render(
      <TestContextProviders siteOptions={{ domain }}>
        <ToggleableModal />
      </TestContextProviders>
    )

    expect(googleKeywordsHandler).toHaveBeenCalledTimes(0)
    act(() => setOpen(true))
    expect(screen.getByText('Google search terms')).toBeVisible()
    expect(googleKeywordsHandler).toHaveBeenCalledTimes(1)
    expect(googleKeywordsHandler).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('limit=100'),
      expect.anything()
    )

    act(() => setOpen(false))
    expect(screen.queryByText('Google search terms')).not.toBeInTheDocument()
    act(() => setOpen(true))
    expect(screen.getByText('Google search terms')).toBeVisible()

    expect(googleKeywordsHandler).toHaveBeenCalledTimes(1)
  })
})
