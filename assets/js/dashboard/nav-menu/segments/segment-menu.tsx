/** @format */

import React from 'react'
import classNames from 'classnames'
import { useSegmentExpandedContext } from '../../segments/segment-expanded-context'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../../components/popover'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import {
  CheckIcon,
  Square2StackIcon,
  TrashIcon,
  XMarkIcon
} from '@heroicons/react/24/outline'
import { ChevronDownIcon } from '@heroicons/react/20/solid'

const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.roundedStartEnd
)
const buttonClassName = classNames(
  'text-white font-medium bg-indigo-600 hover:bg-indigo-700'
)

export const SegmentMenu = () => {
  const { expandedSegment, setModal } = useSegmentExpandedContext()

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
            <Popover.Button
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
            </Popover.Button>
            <Transition
              {...popover.transition.props}
              className={classNames(
                'mt-2',
                popover.transition.classNames.fullwidth,
                'md:w-auto md:left-auto'
              )}
            >
              <Popover.Panel className={popover.panel.classNames.roundedSheet}>
                <AppNavigationLink
                  className={linkClassName}
                  search={(s) => s}
                  state={{ expandedSegment }}
                  onClick={() => {
                    closeDropdown()
                    setModal('update')
                  }}
                >
                  <div className="flex items-center gap-x-2">
                    <CheckIcon className="w-4 h-4 block" />
                    <span className="whitespace-nowrap">Update segment</span>
                  </div>
                </AppNavigationLink>
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
                    // filters: [[['is', 'segment', [expandedSegment.id]]]],
                    // labels: {
                    //   [formatSegmentIdAsLabelKey(expandedSegment.id)]:
                    //     expandedSegment.name
                    // }
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
              </Popover.Panel>
            </Transition>
          </>
        )}
      </Popover>
    </div>
  )
}
