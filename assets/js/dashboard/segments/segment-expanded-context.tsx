/* @format */
import React, {
  createContext,
  ReactNode,
  useContext,
  useLayoutEffect,
  useState
} from 'react'
import { useLocation } from 'react-router-dom'
import { SavedSegment } from './segments'
import { useQueryContext } from '../query-context'

export type SegmentExpandedLocationState = {
  expandedSegment: SavedSegment | null
  modal: 'create' | 'update' | 'delete' | null
}

const segmentExpandedContextDefaultValue: SegmentExpandedLocationState = {
  expandedSegment: null,
  modal: null
}

const SegmentExpandedContext = createContext<
  typeof segmentExpandedContextDefaultValue
>(segmentExpandedContextDefaultValue)

export const useSegmentExpandedContext = () => {
  return useContext(SegmentExpandedContext)
}

export default function SegmentExpandedContextProvider({
  children
}: {
  children: ReactNode
}) {
  const { query } = useQueryContext()

  const { state: locationState } = useLocation() as {
    state?: SegmentExpandedLocationState
  }
  
  const [expandedSegment, setExpandedSegment] = useState<SavedSegment | null>(
    null
  )

  useLayoutEffect(() => {
    if (locationState?.expandedSegment) {
      setExpandedSegment(locationState?.expandedSegment)
    }
    if (locationState?.expandedSegment === null) {
      setExpandedSegment(null)
    }
  }, [locationState?.expandedSegment])

  useLayoutEffect(() => {
    if (!query.filters.length) {
      setExpandedSegment(null)
    }
  }, [query.filters.length])

  return (
    <SegmentExpandedContext.Provider
      value={{ expandedSegment: expandedSegment, modal: locationState?.modal ?? null }}
    >
      {children}
    </SegmentExpandedContext.Provider>
  )
}
