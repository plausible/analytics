import React, { Fragment } from 'react';
import { Menu, Transition } from '@headlessui/react'
import { AdjustmentsIcon, PlusIcon } from '@heroicons/react/solid'
import classNames from 'classnames'
import { withRouter, Link } from 'react-router-dom'

import { FILTER_GROUPS, formatFilterGroup } from './stats/modals/filter'

function filterDropdownOption(site, option) {
  return (
    <Menu.Item>
      {({ active }) => (
        <Link
          to={{ pathname: `/${encodeURIComponent(site.domain)}/filter/${option}`, search: window.location.search }}
          className={classNames(
            active ? 'bg-gray-100 text-gray-900' : 'text-gray-700 dark:text-gray-300',
            'block px-4 py-2 text-sm'
          )}
        >
          {formatFilterGroup(option)}
        </Link>
      )}
    </Menu.Item>
  )
}

export function FilterDropdown({site, className}) {
  return (
    <Menu as="div" className={classNames('relative', className)}>
      {({ open }) => (
        <>
          <div>
            <Menu.Button className="flex items-center text-xs md:text-sm font-medium leading-tight px-3 py-2 mr-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded">
              <PlusIcon className="-ml-1 mr-1 h-4 w-4 md:h-5 md:w-5" aria-hidden="true" />
              Add filter
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
              className="origin-top-right z-10 absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-900 ring-1 ring-black ring-opacity-5 focus:outline-none"
            >
              <div className="py-1">
                { Object.keys(FILTER_GROUPS).map((option) => filterDropdownOption(site, option)) }
              </div>
            </Menu.Items>
          </Transition>
        </>
      )}
    </Menu>
  )
}

export function MobileFiltersLink({site, onClick}) {
  return (
    <span
      onClick={onClick}
      className="inline-flex md:hidden items-center text-xs md:text-sm font-medium px-3 py-2 mr-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded"
    >
      <AdjustmentsIcon className="-ml-1 mr-1 h-4 w-4" aria-hidden="true" />
      Filters
    </span>
  )
}
