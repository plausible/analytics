import React, { useEffect } from 'react'
import classNames from 'classnames'
import {
  Popover,
  PopoverButton,
  PopoverPanel,
  Transition
} from '@headlessui/react'
import { popover } from '../../components/popover'
import {
  AppNavigationLink,
  useAppNavigate
} from '../../navigation/use-app-navigate'
import {
  Square2StackIcon,
  TrashIcon,
  XMarkIcon
} from '@heroicons/react/24/outline'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { useQueryContext } from '../../query-context'
import { useRoutelessModalsContext } from '../../navigation/routeless-modals-context'
import { SavedSegment } from '../../filtering/segments'
import { DashboardQuery } from '../../query'

const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.roundedStartEnd
)
const buttonClassName = classNames(
  'text-white font-medium bg-indigo-600 hover:bg-indigo-700'
)

export const useClearExpandedSegmentModeOnFilterClear = ({
  expandedSegment,
  query
}: {
  expandedSegment: SavedSegment | null
  query: DashboardQuery
}) => {
  const navigate = useAppNavigate()
  useEffect(() => {
    // clear edit mode on clearing all filters or removing last filter
    if (!!expandedSegment && !query.filters.length) {
      navigate({
        search: (s) => s,
        state: {
          expandedSegment: null
        },
        replace: true
      })
    }
  }, [query.filters, expandedSegment, navigate])
}

export const SegmentMenu = () => {
  const { setModal } = useRoutelessModalsContext()
  const { expandedSegment } = useQueryContext()

  if (!expandedSegment) {
    return null
  }

  return (
    <div className="flex shadow">
      <AppNavigationLink
        className={classNames(
          popover.toggleButton.classNames.rounded,
          buttonClassName,
          'rounded-r-none',
          'position:relative focus:z-10'
        )}
        search={(s) => s}
        state={{ expandedSegment }}
        onClick={() => {
          setModal('update')
        }}
      >
        <span className="px-2 whitespace-nowrap">Update segment</span>
      </AppNavigationLink>
      <Popover className="md:relative">
        {({ close: closeDropdown }) => (
          <>
            <PopoverButton
              className={classNames(
                popover.toggleButton.classNames.rounded,
                buttonClassName,
                'rounded-l-none',
                'border-1 border-l border-indigo-800',
                'w-9 justify-center'
              )}
            >
              <ChevronDownIcon
                className="w-4 h-4 md:h-5 md:w-5 block"
                aria-hidden="true"
              />
            </PopoverButton>
            <Transition
              as="div"
              {...popover.transition.props}
              className={classNames(
                'mt-2',
                popover.transition.classNames.fullwidth,
                'md:w-auto md:left-auto'
              )}
            >
              <PopoverPanel className={popover.panel.classNames.roundedSheet}>
                <AppNavigationLink
                  className={linkClassName}
                  search={(s) => s}
                  state={{ expandedSegment }}
                  onClick={() => {
                    closeDropdown()
                    setModal('create')
                  }}
                >
                  <div className="flex items-center gap-x-2">
                    <Square2StackIcon className="w-4 h-4 block" />
                    <span className="whitespace-nowrap">
                      Save as a new segment
                    </span>
                  </div>
                </AppNavigationLink>
                <AppNavigationLink
                  className={linkClassName}
                  search={(s) => s}
                  state={{ expandedSegment }}
                  onClick={() => {
                    closeDropdown()
                    setModal('delete')
                  }}
                >
                  <div className="flex items-center gap-x-2">
                    <TrashIcon className="w-4 h-4 block" />
                    <span className="whitespace-nowrap">Delete segment</span>
                  </div>
                </AppNavigationLink>
                <AppNavigationLink
                  className={linkClassName}
                  search={(s) => ({
                    ...s,
                    filters: [],
                    labels: {}
                  })}
                  state={{ expandedSegment: null }}
                  onClick={closeDropdown}
                >
                  <div className="flex items-center gap-x-2">
                    <XMarkIcon className="w-4 h-4 block" />
                    <span className="whitespace-nowrap">
                      Close without saving
                    </span>
                  </div>
                </AppNavigationLink>
              </PopoverPanel>
            </Transition>
          </>
        )}
      </Popover>
    </div>
  )
}
