import React, { Fragment } from "react";

import { FILTER_TYPES } from "../util/filters";
import { Menu, Transition } from "@headlessui/react";
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { isFreeChoiceFilter, supportsIsNot } from "../util/filters";
import classNames from "classnames";

export default function FilterTypeSelector(props) {
  const filterName = props.forFilter

  function renderTypeItem(type, shouldDisplay) {
    return (
      shouldDisplay && (
        <Menu.Item>
          {({ active }) => (
            <span
              onClick={() => props.onSelect(type)}
              className={classNames(
                active ? "bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100" : "text-gray-700 dark:text-gray-200",
                "cursor-pointer block px-4 py-2 text-sm"
              )}
            >
              {type}
            </span>
          )}
        </Menu.Item>
      )
    )
  }

  return (
    <Menu as="div" className="relative inline-block text-left">
      {({ open }) => (
        <>
          <div className="w-24">
            <Menu.Button className="inline-flex justify-between items-center w-full rounded-md border border-gray-300 dark:border-gray-500 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-850 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 dark:focus:ring-offset-gray-900 focus:ring-indigo-500">
              {props.selectedType}
              <ChevronDownIcon className="-mr-2 ml-2 h-4 w-4 text-gray-500 dark:text-gray-400" aria-hidden="true" />
            </Menu.Button>
          </div>

          <Transition
            show={open}
            as={Fragment}
            enter="transition ease-out duration-100"
            enterFrom="transform opacity-0 scale-95"
            enterTo="transform opacity-100 scale-100"
            leave="transition ease-in duration-75"
            leaveFrom="transform opacity-100 scale-100"
            leaveTo="transform opacity-0 scale-95"
          >
            <Menu.Items
              static
              className="z-10 origin-top-left absolute left-0 mt-2 w-24 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none"
            >
              <div className="py-1">
                {renderTypeItem(FILTER_TYPES.is, true)}
                {renderTypeItem(FILTER_TYPES.isNot, supportsIsNot(filterName))}
                {renderTypeItem(FILTER_TYPES.contains, isFreeChoiceFilter(filterName))}
              </div>
            </Menu.Items>
          </Transition>
        </>
      )}
    </Menu>
  )
}