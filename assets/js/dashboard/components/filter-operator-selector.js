import React, { Fragment, useRef } from 'react'

import {
  FILTER_OPERATIONS,
  FILTER_OPERATIONS_DISPLAY_NAMES,
  supportsContains,
  supportsIsNot,
  supportsHasDoneNot
} from '../util/filters'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { BlurMenuButtonOnEscape } from '../keybinding'

export default function FilterOperatorSelector(props) {
  const filterName = props.forFilter
  const buttonRef = useRef()

  function renderTypeItem(operation, shouldDisplay) {
    return (
      shouldDisplay && (
        <Menu.Item>
          {({ active }) => (
            <span
              onClick={() => props.onSelect(operation)}
              className={classNames('cursor-pointer block px-4 py-2 text-sm', {
                'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100':
                  active,
                'text-gray-700 dark:text-gray-200': !active
              })}
            >
              {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}
            </span>
          )}
        </Menu.Item>
      )
    )
  }

  const containerClass = classNames('w-full', {
    'opacity-20 cursor-default pointer-events-none': props.isDisabled
  })

  return (
    <div className={containerClass}>
      <Menu as="div" className="relative inline-block text-left w-full">
        {({ open }) => (
          <>
            <BlurMenuButtonOnEscape targetRef={buttonRef} />
            <div className="w-full">
              <Menu.Button
                ref={buttonRef}
                className="inline-flex justify-between items-center w-full rounded-md border border-gray-300 dark:border-gray-500 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-850 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 dark:focus:ring-offset-gray-900 focus:ring-indigo-500 text-left"
              >
                {FILTER_OPERATIONS_DISPLAY_NAMES[props.selectedType]}
                <ChevronDownIcon
                  className="-mr-2 ml-2 h-4 w-4 text-gray-500 dark:text-gray-400"
                  aria-hidden="true"
                />
              </Menu.Button>
            </div>

            <Transition
              show={open}
              as={Fragment}
              enter="transition ease-out duration-100"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="transition ease-in duration-75"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Menu.Items
                static
                className="z-10 origin-top-left absolute left-0 mt-2 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none"
              >
                <div className="py-1">
                  {renderTypeItem(FILTER_OPERATIONS.is, true)}
                  {renderTypeItem(
                    FILTER_OPERATIONS.isNot,
                    supportsIsNot(filterName)
                  )}
                  {renderTypeItem(
                    FILTER_OPERATIONS.has_not_done,
                    supportsHasDoneNot(filterName)
                  )}
                  {renderTypeItem(
                    FILTER_OPERATIONS.contains,
                    supportsContains(filterName)
                  )}
                  {renderTypeItem(
                    FILTER_OPERATIONS.contains_not,
                    supportsContains(filterName) && supportsIsNot(filterName)
                  )}
                </div>
              </Menu.Items>
            </Transition>
          </>
        )}
      </Menu>
    </div>
  )
}
