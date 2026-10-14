import React, { useEffect } from 'react'
import classNames from 'classnames'
import { popover } from '../../components/popover'
import {
  AppNavigationLink,
  useAppNavigate
} from '../../navigation/use-app-navigate'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useRoutelessModalsContext } from '../../navigation/routeless-modals-context'
import {
  getSearchToSetSegmentFilter,
  SavedSegment
} from '../../filtering/segments'
import { DashboardState } from '../../dashboard-state'

const primaryButtonClassName = classNames(
  popover.toggleButton.classNames.rounded,
  'px-2.5 font-medium whitespace-nowrap text-white bg-indigo-600 hover:bg-indigo-700'
)
const secondaryButtonClassName = classNames(
  popover.toggleButton.classNames.rounded,
  popover.toggleButton.classNames.outline,
  'px-2.5 font-medium whitespace-nowrap'
)

export const useClearExpandedSegmentModeOnFilterClear = ({
  expandedSegment,
  dashboardState
}: {
  expandedSegment: SavedSegment | null
  dashboardState: DashboardState
}) => {
  const navigate = useAppNavigate()
  useEffect(() => {
    // clear edit mode on clearing all filters or removing last filter
    if (!!expandedSegment && !dashboardState.filters.length) {
      navigate({
        search: (s) => s,
        state: {
          expandedSegment: null
        },
        replace: true
      })
    }
  }, [dashboardState.filters, expandedSegment, navigate])
}

export const SegmentMenu = () => {
  const { setModal } = useRoutelessModalsContext()
  const { expandedSegment } = useDashboardStateContext()

  if (!expandedSegment) {
    return null
  }

  return (
    <div className="flex items-center gap-x-1 md:gap-x-2">
      <button
        type="button"
        className={primaryButtonClassName}
        onClick={() => setModal({ type: 'update-segment' })}
      >
        Save
      </button>
      <AppNavigationLink
        className={secondaryButtonClassName}
        search={getSearchToSetSegmentFilter(expandedSegment, {
          omitAllOtherFilters: true
        })}
        state={{ expandedSegment: null }}
      >
        Cancel
      </AppNavigationLink>
    </div>
  )
}
