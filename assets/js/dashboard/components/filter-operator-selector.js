import React, { useRef } from 'react'

import {
  FILTER_OPERATIONS,
  FILTER_OPERATIONS_DISPLAY_NAMES,
  supportsContains,
  supportsIsNot,
  supportsHasDoneNot
} from '../util/filters'
import {
  Transition,
  PopoverButton,
  PopoverPanel,
  Popover,
  CloseButton
} from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { BlurMenuButtonOnEscape } from '../keybinding'
import { popover } from './popover'

export default function FilterOperatorSelector(props) {
  const filterName = props.forFilter
  const buttonRef = useRef()

  return (
    <div
      className={classNames('w-full', {
        'opacity-20 cursor-default pointer-events-none': props.isDisabled
      })}
    >
      <Popover className="relative w-full">
        <BlurMenuButtonOnEscape targetRef={buttonRef} />
        <PopoverButton
          ref={buttonRef}
          className="relative flex justify-between items-center w-full rounded-md border border-gray-300 dark:border-gray-500 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-850 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 dark:focus:ring-offset-gray-900 focus:ring-indigo-500 text-left"
        >
          {FILTER_OPERATIONS_DISPLAY_NAMES[props.selectedType]}
          <ChevronDownIcon
            className="-mr-2 ml-2 h-4 w-4 text-gray-500 dark:text-gray-400"
            aria-hidden="true"
          />
        </PopoverButton>
        <Transition
          as="div"
          {...popover.transition.props}
          className={classNames(popover.transition.classNames.left, 'mt-2')}
        >
          <PopoverPanel className={classNames(popover.panel.classNames.roundedSheet, 'font-normal')}>
            {[
              [FILTER_OPERATIONS.is, true],
              [FILTER_OPERATIONS.isNot, supportsIsNot(filterName)],
              [FILTER_OPERATIONS.has_not_done, supportsHasDoneNot(filterName)],
              [FILTER_OPERATIONS.contains, supportsContains(filterName)],
              [
                FILTER_OPERATIONS.contains_not,
                supportsContains(filterName) && supportsIsNot(filterName)
              ]
            ]
              .filter(([_operation, supported]) => supported)
              .map(([operation]) => (
                <CloseButton
                  as="button"
                  key={operation}
                  data-selected={operation === props.selectedType}
                  onClick={(e) => {
                    // Prevent the click propagating and closing modal
                    e.preventDefault()
                    e.stopPropagation()
                    props.onSelect(operation)
                  }}
                  className={classNames(
                    'w-full text-left ',
                    popover.items.classNames.navigationLink,
                    popover.items.classNames.selectedOption,
                    popover.items.classNames.hoverLink,
                    popover.items.classNames.roundedStartEnd
                  )}
                >
                  {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}
                </CloseButton>
              ))}
          </PopoverPanel>
        </Transition>
      </Popover>
    </div>
  )
}
