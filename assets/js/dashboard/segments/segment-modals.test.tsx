import React from 'react'
import { render, screen } from '@testing-library/react'
import { SegmentModal } from './segment-modals'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import {
  SavedSegment,
  SavedSegmentPublic,
  SavedSegments,
  SegmentData,
  SegmentType
} from '../filtering/segments'
import { Role, UserContextValue } from '../user-context'
import { PlausibleSite } from '../site-context'

beforeEach(() => {
  const modalRoot = document.createElement('div')
  modalRoot.id = 'modal_root'
  document.body.appendChild(modalRoot)
})

describe('Segment details modal - errors', () => {
  const anySegment: SavedSegment & { segment_data: SegmentData } = {
    id: 1,
    type: SegmentType.site,
    owner_id: 1,
    owner_name: 'Test User',
    name: 'Blog or About',
    segment_data: {
      filters: [['is', 'page', ['/blog', '/about']]],
      labels: {}
    },
    inserted_at: '2025-03-13T13:00:00',
    updated_at: '2025-03-13T16:00:00'
  }

  const anyPersonalSegment: SavedSegment & { segment_data: SegmentData } = {
    ...anySegment,
    id: 2,
    type: SegmentType.personal
  }

  const cases: {
    case: string
    segments: SavedSegments
    segmentId: number
    user: UserContextValue
    message: string
    siteOptions: Partial<PlausibleSite>
  }[] = [
    {
      case: 'segment is not in list',
      segments: [anyPersonalSegment, anySegment],
      segmentId: 202020,
      user: {
        loggedIn: true,
        id: 1,
        role: Role.owner,
        team: { identifier: null, hasConsolidatedView: false }
      },
      message: `Segment not found with with ID "202020"`,
      siteOptions: { siteSegmentsAvailable: true }
    }
  ]
  it.each(cases)(
    'shows error `$message` when $case',
    ({ user, segments, segmentId, message, siteOptions }) => {
      render(<SegmentModal id={segmentId} />, {
        wrapper: (props) => (
          <TestContextProviders
            user={user}
            preloaded={{ segments }}
            siteOptions={siteOptions}
            {...props}
          />
        )
      })

      expect(screen.getByText(message)).toBeVisible()
      expect(screen.queryByText(`Edit segment`)).not.toBeInTheDocument()
    }
  )
})

describe('Segment details modal - other cases', () => {
  it.each([
    [SegmentType.site, 'Site segment'],
    [SegmentType.personal, 'Personal segment']
  ])(
    'displays segment with type %s correctly for logged in user',
    (segmentType, expectedSegmentTypeText) => {
      const user: UserContextValue = {
        loggedIn: true,
        role: Role.editor,
        id: 1,
        team: { identifier: null, hasConsolidatedView: false }
      }
      const anySegment: SavedSegment & { segment_data: SegmentData } = {
        id: 100,
        type: segmentType,
        owner_id: user.id,
        owner_name: 'Jane Smith',
        name: 'Blog or About',
        segment_data: {
          filters: [['is', 'page', ['/blog', '/about']]],
          labels: {}
        },
        inserted_at: '2025-03-13T13:00:00',
        updated_at: '2025-03-13T16:00:00'
      }

      render(<SegmentModal id={anySegment.id} />, {
        wrapper: (props) => (
          <TestContextProviders
            user={user}
            preloaded={{
              segments: [anySegment]
            }}
            siteOptions={{ siteSegmentsAvailable: true }}
            {...props}
          />
        )
      })
      expect(screen.getByText(anySegment.name)).toBeVisible()
      expect(screen.getByText(expectedSegmentTypeText)).toBeVisible()

      expect(screen.getByText('Filters in segment')).toBeVisible()
      expect(screen.getByTitle('Page is /blog or /about')).toBeVisible()

      expect(
        screen.getByText(`Last updated at 13 Mar by ${anySegment.owner_name}`)
      ).toBeVisible()
      expect(screen.getByText(`Created at 13 Mar`)).toBeVisible()

      expect(screen.getByText('Edit segment')).toBeVisible()
      expect(screen.getByText('Remove filter')).toBeVisible()
    }
  )

  it.each([
    [SegmentType.site, 'Site segment'],
    [SegmentType.personal, 'Personal segment']
  ])(
    'displays segment with type %s correctly for public role',
    (segmentType, expectedSegmentTypeText) => {
      const user: UserContextValue = {
        loggedIn: false,
        role: Role.public,
        id: null,
        team: { identifier: null, hasConsolidatedView: false }
      }
      const anySegment: SavedSegment & { segment_data: SegmentData } = {
        id: 100,
        type: segmentType,
        owner_id: null,
        owner_name: null,
        name: 'Blog or About',
        segment_data: {
          filters: [['is', 'page', ['/blog', '/about']]],
          labels: {}
        },
        inserted_at: '2025-03-13T13:00:00',
        updated_at: '2025-03-13T16:00:00'
      }

      render(<SegmentModal id={anySegment.id} />, {
        wrapper: (props) => (
          <TestContextProviders
            user={user}
            preloaded={{
              segments: [anySegment]
            }}
            siteOptions={{ siteSegmentsAvailable: true }}
            {...props}
          />
        )
      })
      expect(screen.getByText(anySegment.name)).toBeVisible()
      expect(screen.getByText(expectedSegmentTypeText)).toBeVisible()

      expect(screen.getByText('Filters in segment')).toBeVisible()
      expect(screen.getByTitle('Page is /blog or /about')).toBeVisible()

      expect(screen.getByText(`Last updated at 13 Mar`)).toBeVisible()
      expect(screen.queryByText('by ')).toBeNull() // no segment author is shown to public role
      expect(screen.getByText(`Created at 13 Mar`)).toBeVisible()

      expect(screen.getByText('Remove filter')).toBeVisible()
      expect(screen.queryByText('Edit segment')).toBeNull()
    }
  )

  it('allows elevated roles to expand site segments even if site segments are not available on their plan (to update type to personal segment)', () => {
    const user: UserContextValue = {
      loggedIn: true,
      role: Role.owner,
      id: 1,
      team: { identifier: null, hasConsolidatedView: false }
    }
    const anySegment: SavedSegmentPublic & { segment_data: SegmentData } = {
      id: 100,
      type: SegmentType.site,
      owner_id: null,
      owner_name: null,
      name: 'Blog or About',
      segment_data: {
        filters: [['is', 'page', ['/blog', '/about']]],
        labels: {}
      },
      inserted_at: '2025-03-13T13:00:00',
      updated_at: '2025-03-13T16:00:00'
    }

    render(<SegmentModal id={anySegment.id} />, {
      wrapper: (props) => (
        <TestContextProviders
          user={user}
          preloaded={{
            segments: [anySegment]
          }}
          siteOptions={{ siteSegmentsAvailable: false }}
          {...props}
        />
      )
    })
    expect(screen.getByText(anySegment.name)).toBeVisible()
    expect(screen.getByText('Site segment')).toBeVisible()

    expect(screen.getByText('Filters in segment')).toBeVisible()
    expect(screen.getByTitle('Page is /blog or /about')).toBeVisible()

    expect(
      screen.getByText(`Last updated at 13 Mar by (Removed User)`)
    ).toBeVisible()
    expect(screen.getByText(`Created at 13 Mar`)).toBeVisible()

    expect(screen.getByText('Remove filter')).toBeVisible()
    expect(screen.getByText('Edit segment')).toBeVisible()
  })

  it('does not display clear filter button if the dashboard is limited to this segment', () => {
    const user: UserContextValue = {
      loggedIn: false,
      role: Role.public,
      id: null,
      team: { identifier: null, hasConsolidatedView: false }
    }
    const anySegment: SavedSegmentPublic & { segment_data: SegmentData } = {
      id: 100,
      type: SegmentType.site,
      owner_id: null,
      owner_name: null,
      name: 'Blog or About',
      segment_data: {
        filters: [['is', 'page', ['/blog', '/about']]],
        labels: {}
      },
      inserted_at: '2025-03-13T13:00:00',
      updated_at: '2025-03-13T16:00:00'
    }

    render(<SegmentModal id={anySegment.id} />, {
      wrapper: (props) => (
        <TestContextProviders
          user={user}
          preloaded={{
            segments: [anySegment]
          }}
          limitedToSegment={anySegment}
          siteOptions={{ siteSegmentsAvailable: true }}
          {...props}
        />
      )
    })
    expect(screen.getByText(anySegment.name)).toBeVisible()
    expect(screen.getByText('Site segment')).toBeVisible()

    expect(screen.getByText('Filters in segment')).toBeVisible()
    expect(screen.getByTitle('Page is /blog or /about')).toBeVisible()

    expect(screen.getByText(`Last updated at 13 Mar`)).toBeVisible()
    expect(screen.getByText(`Created at 13 Mar`)).toBeVisible()

    expect(screen.queryByText('Remove filter')).toBeNull()
    expect(screen.queryByText('Edit segment')).toBeNull()
  })
})
