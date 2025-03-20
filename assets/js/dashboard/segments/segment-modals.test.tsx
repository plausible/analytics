/** @format */

import React from 'react'
import { render, screen } from '@testing-library/react'
import { SegmentModal } from './segment-modals'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import {
  SavedSegment,
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

const flags = { saved_segments: true, saved_segments_fe: true }

describe('Segment details modal - errors', () => {
  const anySiteSegment: SavedSegment & { segment_data: SegmentData } = {
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
    ...anySiteSegment,
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
      segments: [anyPersonalSegment, anySiteSegment],
      segmentId: 202020,
      user: { loggedIn: true, id: 1, role: Role.owner },
      message: `Segment not found with with ID "202020"`,
      siteOptions: { flags, siteSegmentsAvailable: true }
    },
    {
      case: 'site segment is in list but not listable because site segments are not available',
      segments: [anyPersonalSegment, anySiteSegment],
      segmentId: anySiteSegment.id,
      user: { loggedIn: true, id: 1, role: Role.owner },
      message: `Segment not found with with ID "${anySiteSegment.id}"`,
      siteOptions: { flags, siteSegmentsAvailable: false }
    },
    {
      case: 'personal segment is in list but not listable because it is a public dashboard',
      segments: [{ ...anyPersonalSegment, owner_id: null, owner_name: null }],
      segmentId: anyPersonalSegment.id,
      user: { loggedIn: false, id: null, role: Role.public },
      message: `Segment not found with with ID "${anyPersonalSegment.id}"`,
      siteOptions: { flags, siteSegmentsAvailable: true }
    },
    {
      case: 'segment is in list and listable, but detailed view is not available because user is not logged in',
      segments: [{ ...anySiteSegment, owner_id: null, owner_name: null }],
      segmentId: anySiteSegment.id,
      user: { loggedIn: false, id: null, role: Role.public },
      message: 'Not enough permissions to see segment details',
      siteOptions: { flags, siteSegmentsAvailable: true }
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
  it('displays site segment correctly', () => {
    const anySiteSegment: SavedSegment & { segment_data: SegmentData } = {
      id: 100,
      type: SegmentType.site,
      owner_id: 100100,
      owner_name: 'Test User',
      name: 'Blog or About',
      segment_data: {
        filters: [['is', 'page', ['/blog', '/about']]],
        labels: {}
      },
      inserted_at: '2025-03-13T13:00:00',
      updated_at: '2025-03-13T16:00:00'
    }

    render(<SegmentModal id={anySiteSegment.id} />, {
      wrapper: (props) => (
        <TestContextProviders
          user={{ loggedIn: true, role: Role.editor, id: 1 }}
          preloaded={{
            segments: [anySiteSegment]
          }}
          siteOptions={{ flags, siteSegmentsAvailable: true }}
          {...props}
        />
      )
    })
    expect(screen.getByText(anySiteSegment.name)).toBeVisible()
    expect(screen.getByText('Site segment')).toBeVisible()

    expect(screen.getByText('Filters in segment')).toBeVisible()
    expect(screen.getByTitle('Page is /blog or /about')).toBeVisible()

    expect(
      screen.getByText(`Last updated at 13 Mar by ${anySiteSegment.owner_name}`)
    ).toBeVisible()
    expect(screen.getByText(`Created at 13 Mar`)).toBeVisible()

    expect(screen.getByText('Edit segment')).toBeVisible()
    expect(screen.getByText('Remove filter')).toBeVisible()
  })
})
