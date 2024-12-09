/* @format */
import React, {
  createContext,
  ReactNode,
  useContext,
  useLayoutEffect,
  useState
} from 'react'
import { SavedSegment, SegmentData } from './segments'
import { useLocation, useNavigationType } from 'react-router-dom'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useQueryContext } from '../query-context'

export type SegmentExpandedState = {
  expandedSegment: (SavedSegment & { segment_data: SegmentData }) | null
  modal: 'create' | 'update' | 'delete' | null
}

const segmentExpandedContextDefaultValue: SegmentExpandedState = {
  expandedSegment: null,
  modal: null
}

const SegmentExpandedContext = createContext<
  typeof segmentExpandedContextDefaultValue
>(segmentExpandedContextDefaultValue)

export const useSegmentExpandedContext = () => {
  return useContext(SegmentExpandedContext)
}

// initial state, there's no expandedSegment
// link navigates to expandedSegment
// other links navigate away with no state setting
// --> components receives old expandedSegment
// link navigates

export default function SegmentExpandedContextProvider({
  children
}: {
  children: ReactNode
}) {
  const location = useLocation()
  const type = useNavigationType()
  const navigate = useAppNavigate()
  // const initial = location.state?.expandedSegment
  //   ? {
  //       modal: location.state.modal,
  //       expandedSegment: location.state.expandedSegment
  //     }
  //   : { modal: null, expandedSegment: null }

  const { query } = useQueryContext()
  const [expandedSegmentState, setState] = useState<SegmentExpandedState>()

  useLayoutEffect(() => {
    if (
      (!expandedSegmentState?.expandedSegment &&
        !location.state?.expandedSegment &&
        !location.state?.modal) ||
      !query.filters.length
    ) {
      console.log('resetting')
      navigate({
        search: (s) => s,
        state: segmentExpandedContextDefaultValue,
        replace: true
      })
    }
  }, [navigate, expandedSegmentState, location.state, query.filters])

  useLayoutEffect(() => {
    if (location.state?.expandedSegment || location.state?.modal) {
      setState({
        expandedSegment: location.state.expandedSegment,
        modal: location.state?.modal
      })
      console.log('copying to state')
    }
    if (location.state?.expandedSegment === null && !location.state?.modal) {
      setState(segmentExpandedContextDefaultValue)
    }
    // if (type === 'POP' && location.state?.expandedSegment) {
    //   setState(segmentExpandedContextDefaultValue)
    // }
  }, [location.state, type])

  console.log({ location, type, expandedSegmentState })

  return (
    <SegmentExpandedContext.Provider
      value={expandedSegmentState ?? segmentExpandedContextDefaultValue}
    >
      {children}
    </SegmentExpandedContext.Provider>
  )
}
