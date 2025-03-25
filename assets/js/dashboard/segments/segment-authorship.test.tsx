import React from 'react'
import { render, screen } from '@testing-library/react'
import { SegmentAuthorship } from './segment-authorship'
import { SegmentType } from '../filtering/segments'

describe('public (no "by <user>" shown)', () => {
  const showOnlyPublicData = true

  test('shows only insert date if its the same as updated at', async () => {
    render(
      <SegmentAuthorship
        showOnlyPublicData={showOnlyPublicData}
        segment={{
          type: SegmentType.site,
          name: 'APAC region',
          id: 100,
          owner_id: null,
          owner_name: null,
          inserted_at: '2025-02-01 14:00:00',
          updated_at: '2025-02-01 14:00:00'
        }}
      />
    )

    expect(screen.getByText('Created at 1 Feb')).toBeVisible()
    expect(screen.queryByText(/Last updated/)).toBeNull()
    expect(screen.queryByText(/by /)).toBeNull()
  })

  test('shows both insert date and updated at', async () => {
    render(
      <SegmentAuthorship
        showOnlyPublicData={showOnlyPublicData}
        segment={{
          type: SegmentType.site,
          name: 'APAC region',
          id: 100,
          owner_id: null,
          owner_name: null,
          inserted_at: '2025-02-01 14:00:00',
          updated_at: '2025-02-01 15:00:00'
        }}
      />
    )

    expect(screen.getByText('Created at 1 Feb')).toBeVisible()
    expect(screen.getByText('Last updated at 1 Feb')).toBeVisible()
    expect(screen.queryByText(/by /)).toBeNull()
  })
})

describe('shown to a site member ("by <user>" shown)', () => {
  const showOnlyPublicData = false

  test('shows only insert date if its the same as updated at', async () => {
    render(
      <SegmentAuthorship
        showOnlyPublicData={showOnlyPublicData}
        segment={{
          type: SegmentType.site,
          name: 'APAC region',
          id: 100,
          owner_id: null,
          owner_name: null,
          inserted_at: '2025-02-01 14:00:00',
          updated_at: '2025-02-01 14:00:00'
        }}
      />
    )

    expect(screen.getByText('Created at 1 Feb by (Removed User)')).toBeVisible()
    expect(screen.queryByText(/Last updated/)).toBeNull()
  })

  test('shows both insert date and updated at', async () => {
    render(
      <SegmentAuthorship
        showOnlyPublicData={showOnlyPublicData}
        segment={{
          type: SegmentType.site,
          name: 'APAC region',
          id: 100,
          owner_id: 500,
          owner_name: 'Jane Smith',
          inserted_at: '2025-02-01 14:00:00',
          updated_at: '2025-02-05 15:00:00'
        }}
      />
    )

    expect(screen.getByText('Created at 1 Feb')).toBeVisible()
    expect(
      screen.queryByText('Last updated at 5 Feb by Jane Smith')
    ).toBeVisible()
  })
})
