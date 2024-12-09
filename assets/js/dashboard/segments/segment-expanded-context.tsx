/* @format */
import React, {
  createContext,
  ReactNode,
  useContext,
  useLayoutEffect,
  useState
} from 'react'
import { SavedSegment, SegmentData } from './segments'
import { useQueryContext } from '../query-context'

export type SegmentExpandedState = {
  expandedSegment: (SavedSegment & { segment_data: SegmentData }) | null
  modal: 'create' | 'update' | 'delete' | null
}

const segmentExpandedContextDefaultValue: SegmentExpandedState & {
  setExpandedSegmentState: (s: SegmentExpandedState) => void
} = {
  expandedSegment: null,
  modal: null,
  setExpandedSegmentState: () => {}
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
  console.log('seg rerendering')
  const { query } = useQueryContext()
  console.log(query.filters)
  const [expandedSegmentState, setExpandedSegmentState] =
    useState<SegmentExpandedState>({ modal: null, expandedSegment: null })
  console.log(expandedSegmentState)

  useLayoutEffect(() => {
    if (!query.filters.length) {
      setExpandedSegmentState({ modal: null, expandedSegment: null })
    }
  }, [query.filters.length])

  return (
    <SegmentExpandedContext.Provider
      value={{
        ...expandedSegmentState,
        setExpandedSegmentState
      }}
    >
      {children}
    </SegmentExpandedContext.Provider>
  )
}
