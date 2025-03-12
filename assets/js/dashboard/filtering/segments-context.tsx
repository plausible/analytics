/** @format */
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
  SegmentData
} from './segments'

export function parsePreloadedSegments(dataset: DOMStringMap): Segments {
  return JSON.parse(dataset.segments!).map(handleSegmentResponse)
}

type Segments = Array<
  (SavedSegment | SavedSegmentPublic) & {
    segment_data: SegmentData
  }
>

type ChangeSegmentState = (
  segment: SavedSegment & { segment_data: SegmentData }
) => void

const initialValue: {
  segments: Segments
  updateOne: ChangeSegmentState
  addOne: ChangeSegmentState
  removeOne: ChangeSegmentState
} = {
  segments: [],
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
  children
}: {
  preloadedSegments: Segments
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
      value={{ segments, removeOne, updateOne, addOne }}
    >
      {children}
    </SegmentsContext.Provider>
  )
}
