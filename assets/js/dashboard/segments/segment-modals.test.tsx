import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { DeleteSegmentModal, UpdateSegmentModal } from './segment-modals'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { MockAPI } from '../../../test-utils/mock-api'
import { SavedSegment, SegmentData, SegmentType } from '../filtering/segments'
import { Role, UserContextValue } from '../user-context'

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
  const modalRoot = document.createElement('div')
  modalRoot.id = 'modal_root'
  document.body.appendChild(modalRoot)
})

const owner: UserContextValue = {
  loggedIn: true,
  role: Role.editor,
  id: 1,
  team: { identifier: null, hasConsolidatedView: false }
}

const anySegment: SavedSegment & { segment_data: SegmentData } = {
  id: 100,
  type: SegmentType.personal,
  owner_id: owner.id,
  owner_name: 'Jane Smith',
  name: 'Blog or About',
  segment_data: {
    filters: [['is', 'page', ['/blog', '/about']]],
    labels: {}
  },
  inserted_at: '2025-03-13T13:00:00',
  updated_at: '2025-03-13T16:00:00'
}

describe('Update segment modal', () => {
  it('shows and focuses the segment name', () => {
    render(
      <UpdateSegmentModal
        user={owner}
        siteSegmentsAvailable={true}
        segment={anySegment}
        namePlaceholder="Page is /blog or /about"
        onClose={jest.fn()}
        onSave={jest.fn()}
        status="idle"
        error={null}
        reset={jest.fn()}
      />,
      {
        wrapper: (props) => (
          <TestContextProviders
            user={owner}
            siteOptions={{ siteSegmentsAvailable: true }}
            {...props}
          />
        )
      }
    )

    expect(
      screen.getByRole('heading', { name: 'Update segment' })
    ).toBeVisible()
    expect(screen.getByLabelText('Segment name')).toHaveValue(anySegment.name)
    expect(screen.getByLabelText('Segment name')).toHaveFocus()
  })
})

describe('Delete segment modal', () => {
  it.each([
    {
      case: 'personal segment without shared links',
      type: SegmentType.personal,
      links: [],
      notice: 'Are you sure?',
      checkbox: null,
      deleteButton: 'Delete'
    },
    {
      case: 'site segment without shared links',
      type: SegmentType.site,
      links: [],
      notice:
        'This site segment will be removed for everyone with access to this dashboard. Are you sure?',
      checkbox: null,
      deleteButton: 'Delete'
    },
    {
      case: 'segment with one shared link',
      type: SegmentType.site,
      links: ['Agency link'],
      notice:
        'This segment is used by a shared link. To delete the segment, this link must also be deleted:',
      checkbox: 'Also delete this shared link',
      deleteButton: 'Delete segment and link'
    },
    {
      case: 'segment with more shared links',
      type: SegmentType.site,
      links: ['Agency link', 'Client link'],
      notice:
        'This segment is used by 2 shared links. To delete the segment, these links must also be deleted:',
      checkbox: 'Also delete these 2 shared links',
      deleteButton: 'Delete segment and links'
    }
  ])(
    'shows the correct notice and actions for a $case',
    async ({ type, links, notice, checkbox, deleteButton }) => {
      const segment = { ...anySegment, type }
      mockAPI.get(`/api/${domain}/segments/${segment.id}/shared-links`, links)
      const onSave = jest.fn()

      render(
        <DeleteSegmentModal
          segment={segment}
          onClose={jest.fn()}
          onSave={onSave}
          status="idle"
          error={null}
          reset={jest.fn()}
        />,
        {
          wrapper: (props) => (
            <TestContextProviders
              user={owner}
              siteOptions={{ domain }}
              {...props}
            />
          )
        }
      )

      expect(
        await screen.findByText(notice, { exact: false })
      ).toBeInTheDocument()
      expect(
        links.map((name) =>
          screen.getByRole('link', { name }).getAttribute('href')
        )
      ).toEqual(links.map(() => `/${domain}/settings/visibility`))

      const button = screen.getByRole('button', { name: deleteButton })
      if (checkbox) {
        expect(button).toBeDisabled()
        await userEvent.click(screen.getByLabelText(checkbox))
      } else {
        expect(screen.queryByRole('checkbox')).not.toBeInTheDocument()
      }
      expect(button).toBeEnabled()

      await userEvent.click(button)
      expect(onSave).toHaveBeenCalledWith({ id: segment.id })
    }
  )
})
