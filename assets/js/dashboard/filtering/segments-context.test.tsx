import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { SegmentsContextProvider, useSegmentsContext } from './segments-context'
import { SavedSegment, SegmentData, SegmentType } from './segments'

function TestComponent() {
  const { segments, addOne, removeOne, updateOne } = useSegmentsContext()

  return (
    <div>
      <button onClick={() => addOne(segmentOpenSource)}>Add Segment</button>
      {segments.map((segment) => (
        <div key={segment.id}>
          <span data-testid="name">{segment.name}</span>
          <button onClick={() => removeOne(segment)}>
            Delete {segment.name}
          </button>
          <button
            onClick={() =>
              updateOne({ ...segment, name: `${segment.name} (Updated)` })
            }
          >
            Update {segment.name}
          </button>
        </div>
      ))}
    </div>
  )
}

const getRenderedSegmentNames = () =>
  screen.queryAllByTestId('name').map((e) => e.textContent)

describe('SegmentsContext functions', () => {
  test('deleteOne works', () => {
    render(
      <SegmentsContextProvider
        preloadedSegments={[segmentOpenSource, segmentAPAC]}
      >
        <TestComponent />
      </SegmentsContextProvider>
    )

    expect(getRenderedSegmentNames()).toEqual([
      segmentOpenSource.name,
      segmentAPAC.name
    ])
    fireEvent.click(screen.getByText(`Delete ${segmentOpenSource.name}`))
    expect(getRenderedSegmentNames()).toEqual([segmentAPAC.name])
  })

  test('addOne adds to head of list', async () => {
    render(
      <SegmentsContextProvider preloadedSegments={[segmentAPAC]}>
        <TestComponent />
      </SegmentsContextProvider>
    )

    expect(getRenderedSegmentNames()).toEqual([segmentAPAC.name])

    fireEvent.click(screen.getByText('Add Segment'))
    expect(screen.queryAllByTestId('name').map((e) => e.textContent)).toEqual([
      segmentOpenSource.name,
      segmentAPAC.name
    ])
  })

  test('updateOne works: updated segment is at head of list', () => {
    render(
      <SegmentsContextProvider
        preloadedSegments={[segmentOpenSource, segmentAPAC]}
      >
        <TestComponent />
      </SegmentsContextProvider>
    )

    expect(getRenderedSegmentNames()).toEqual([
      segmentOpenSource.name,
      segmentAPAC.name
    ])
    fireEvent.click(screen.getByText(`Update ${segmentAPAC.name}`))
    expect(getRenderedSegmentNames()).toEqual([
      `${segmentAPAC.name} (Updated)`,
      segmentOpenSource.name
    ])
  })
})

const segmentAPAC: SavedSegment & { segment_data: SegmentData } = {
  id: 1,
  name: 'APAC region',
  type: SegmentType.personal,
  owner_id: 100,
  owner_name: 'Test User',
  inserted_at: '2025-03-10T10:00:00',
  updated_at: '2025-03-11T10:00:00',
  segment_data: {
    filters: [['is', 'country', ['JP', 'NZ']]],
    labels: { JP: 'Japan', NZ: 'New Zealand' }
  }
}

const segmentOpenSource: SavedSegment & { segment_data: SegmentData } = {
  id: 2,
  name: 'Open source fans',
  type: SegmentType.site,
  owner_id: 200,
  owner_name: 'Other User',
  inserted_at: '2025-03-11T10:00:00',
  updated_at: '2025-03-12T10:00:00',
  segment_data: {
    filters: [
      ['is', 'browser', ['Firefox']],
      ['is', 'os', ['Linux']]
    ],
    labels: {}
  }
}
