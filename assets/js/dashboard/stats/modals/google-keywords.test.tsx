import React, { useState, Dispatch, SetStateAction } from 'react'
import { act, render, waitFor } from '@testing-library/react'
import {
  mockAnimationsApi,
  mockResizeObserver,
  mockIntersectionObserver
} from 'jsdom-testing-mocks'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import GoogleKeywordsModal from './google-keywords'

mockAnimationsApi()
mockResizeObserver()
mockIntersectionObserver()

const fetchMock = jest.fn()

beforeAll(() => {
  globalThis.fetch = fetchMock
})

beforeEach(() => {
  const modalRoot = document.createElement('div')
  modalRoot.setAttribute('id', 'modal_root')
  document.body.appendChild(modalRoot)

  fetchMock.mockImplementation((url: string) => {
    if (url.includes('/referrers/Google/')) {
      return Promise.resolve({
        ok: true,
        status: 200,
        json: async () => ({ results: [] })
      })
    }
    throw new Error(`Unmocked request: ${url}`)
  })
})

afterEach(() => {
  document.getElementById('modal_root')?.remove()
})

describe('GoogleKeywordsModal', () => {
  test('opening the modal for a second time with the same dashboardState gets response from cache', async () => {
    let setOpen: Dispatch<SetStateAction<boolean>>

    function ToggleableModal() {
      const [open, s] = useState(true)
      setOpen = s
      return open ? <GoogleKeywordsModal /> : null
    }

    render(
      <TestContextProviders>
        <ToggleableModal />
      </TestContextProviders>
    )

    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1))

    act(() => setOpen(false))
    act(() => setOpen(true))

    await act(async () => {})

    expect(fetchMock).toHaveBeenCalledTimes(1)
  })
})
