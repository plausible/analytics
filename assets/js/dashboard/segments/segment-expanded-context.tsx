/* @format */
import React, {
  createContext,
  ReactNode,
  useContext,
  useEffect,
  useState
} from 'react'
import { SavedSegment, SegmentData } from '../filtering/segments'
import { useLocation } from 'react-router-dom'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useQueryContext } from '../query-context'

export type SegmentExpandedState = {
  expandedSegment: (SavedSegment & { segment_data: SegmentData }) | null
}

export type SegmentModalState = null | 'create' | 'update' | 'delete'

const segmentExpandedContextDefaultValue: SegmentExpandedState & {
  modal: SegmentModalState
  setModal: (modal: SegmentModalState) => void
} = {
  expandedSegment: null,
  modal: null,
  setModal: () => {}
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
  const location = useLocation()
  const [expandedSegmentState, setState] = useState<SegmentExpandedState>({
    expandedSegment: segmentExpandedContextDefaultValue.expandedSegment
  })
  const [modal, setModal] = useState<SegmentModalState>(
    segmentExpandedContextDefaultValue.modal
  )

  const { query } = useQueryContext()
  const navigate = useAppNavigate()

  const locationStateExpandedSegment = location.state?.expandedSegment

  useEffect(() => {
    // copy location.state to state
    if (locationStateExpandedSegment) {
      setState({
        expandedSegment: locationStateExpandedSegment
      })
    }
    if (locationStateExpandedSegment === null) {
      setState({
        expandedSegment: segmentExpandedContextDefaultValue.expandedSegment
      })
      // setModal(segmentExpandedContextDefaultValue.modal)
    }
  }, [locationStateExpandedSegment])

  useEffect(() => {
    // clear edit mode on clearing all filters
    if (!query.filters.length && expandedSegmentState.expandedSegment) {
      navigate({
        search: (s) => s,
        state: {
          expandedSegment: segmentExpandedContextDefaultValue.expandedSegment
        },
        replace: true
      })
      // overwrite undefined locationState with current expandedSegment, to handle Back navigation correctly
    } else if (locationStateExpandedSegment === undefined) {
      // console.log('Slowness')
      navigate({
        search: (s) => s,
        state: {
          expandedSegment: expandedSegmentState.expandedSegment
        },
        replace: true
      })
    }
  }, [
    query,
    expandedSegmentState.expandedSegment,
    navigate,
    locationStateExpandedSegment
  ])

  return (
    <SegmentExpandedContext.Provider
      value={{
        expandedSegment: expandedSegmentState.expandedSegment,
        modal,
        setModal
      }}
    >
      {children}
    </SegmentExpandedContext.Provider>
  )
}
