import React, { useState, Dispatch, SetStateAction } from 'react'
import { act, render, screen } from '@testing-library/react'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import PagesModal from './pages'
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

describe('BreakdownModal', () => {
  test('opening the modal for a second time with the same dashboardState gets response from cache', async () => {
    const response = {
      results: [],
      meta: { date_range_label: 'Last 30 days', metric_warnings: undefined }
    }

    const pagesHandler = mockAPI.get(`/api/stats/${domain}/pages/`, response)

    let setOpen: Dispatch<SetStateAction<boolean>>

    function ToggleableModal() {
      const [open, s] = useState(false)
      setOpen = s
      return open ? <PagesModal /> : null
    }

    render(
      <TestContextProviders siteOptions={{ domain }}>
        <ToggleableModal />
      </TestContextProviders>
    )

    expect(pagesHandler).toHaveBeenCalledTimes(0)
    act(() => setOpen(true))
    expect(screen.getByText('Top pages')).toBeVisible()
    expect(pagesHandler).toHaveBeenCalledTimes(1)
    expect(pagesHandler).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining(
        'order_by=%5B%5B%22visitors%22%2C%22desc%22%5D%5D&limit=100&page=1'
      ),
      expect.anything()
    )

    act(() => setOpen(false))
    expect(screen.queryByText('Top pages')).not.toBeInTheDocument()
    act(() => setOpen(true))
    expect(screen.getByText('Top pages')).toBeVisible()

    expect(pagesHandler).toHaveBeenCalledTimes(1)
  })
})
