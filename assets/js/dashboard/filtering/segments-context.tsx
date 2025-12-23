import React, {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useState
} from 'react'
import {
  handleSegmentResponse,
  SavedSegment,
  SavedSegmentPublic,
  SavedSegments,
  SegmentData
} from './segments'

export function parsePreloadedSegments(dataset: DOMStringMap): SavedSegments {
  return JSON.parse(dataset.segments!).map(handleSegmentResponse)
}

export function parseLimitedToSegmentId(dataset: DOMStringMap): number | null {
  return JSON.parse(dataset.limitedToSegmentId!)
}

export function getLimitedToSegment(
  limitedToSegmentId: number | null,
  preloadedSegments: SavedSegments
): Pick<SavedSegment, 'id' | 'name'> | null {
  if (limitedToSegmentId !== null) {
    return preloadedSegments.find((s) => s.id === limitedToSegmentId) ?? null
  }
  return null
}

type ChangeSegmentState = (
  segment: (SavedSegment | SavedSegmentPublic) & { segment_data: SegmentData }
) => void

const initialValue: {
  segments: SavedSegments
  limitedToSegment: Pick<SavedSegment, 'id' | 'name'> | null
  updateOne: ChangeSegmentState
  addOne: ChangeSegmentState
  removeOne: ChangeSegmentState
} = {
  segments: [],
  limitedToSegment: null,
  updateOne: () => {},
  addOne: () => {},
  removeOne: () => {}
}

const SegmentsContext = createContext(initialValue)

export const useSegmentsContext = () => {
  return useContext(SegmentsContext)
}

export const SegmentsContextProvider = ({
  preloadedSegments,
  limitedToSegment,
  children
}: {
  preloadedSegments: SavedSegments
  limitedToSegment: Pick<SavedSegment, 'id' | 'name'> | null
  children: ReactNode
}) => {
  const [segments, setSegments] = useState(preloadedSegments)

  const removeOne: ChangeSegmentState = useCallback(
    ({ id }) =>
      setSegments((currentSegments) =>
        currentSegments.filter((s) => s.id !== id)
      ),
    []
  )

  const updateOne: ChangeSegmentState = useCallback(
    (segment) =>
      setSegments((currentSegments) => [
        segment,
        ...currentSegments.filter((s) => s.id !== segment.id)
      ]),
    []
  )

  const addOne: ChangeSegmentState = useCallback(
    (segment) =>
      setSegments((currentSegments) => [segment, ...currentSegments]),
    []
  )

  return (
    <SegmentsContext.Provider
      value={{
        segments,
        limitedToSegment,
        removeOne,
        updateOne,
        addOne
      }}
    >
      {children}
    </SegmentsContext.Provider>
  )
}
