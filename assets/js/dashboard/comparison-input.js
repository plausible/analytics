import React, { Fragment } from 'react'
import { withRouter } from "react-router-dom";
import { navigateToQuery } from './query'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

const COMPARISON_MODES = {
  'previous_period': 'Previous period',
  'year_over_year': 'Year over year',
}

export const COMPARISON_DISABLED_PERIODS = ['realtime', 'all']

const ComparisonInput = function({ site, query, history }) {
  if (!site.flags.comparisons) return null
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return null

  function update(key) {
    navigateToQuery(history, query, { comparison: key })
  }

  function renderItem({ label, value, isCurrentlySelected }) {
    const labelClass = classNames("font-medium text-sm", { "font-bold disabled": isCurrentlySelected })

    return (
      <Menu.Item
        key={value}
        onClick={() => update(value)}
        className="px-4 py-2 leading-tight hover:bg-gray-100 dark:text-white hover:text-gray-900 dark:hover:bg-gray-900 dark:hover:text-gray-100 flex hover:cursor-pointer">
        <span className={labelClass}>{ label }</span>
      </Menu.Item>
    )
  }

  return (
    <div className="flex ml-auto pl-2">
    <div className="w-20 sm:w-36 md:w-48 md:relative">
      <Menu as="div" className="relative inline-block pl-2 w-full">
        <Menu.Button className="bg-white text-gray-800 text-xs md:text-sm font-medium dark:bg-gray-800 dark:hover:bg-gray-900 dark:text-gray-200 hover:bg-gray-200 flex md:px-3 px-2 py-2 items-center justify-between leading-tight rounded shadow truncate cursor-pointer w-full">
          <span>{ COMPARISON_MODES[query.comparison] || 'Compare to' }</span>
          <ChevronDownIcon className="hidden sm:inline-block h-4 w-4 md:h-5 md:w-5 text-gray-500 ml-5" />
        </Menu.Button>
        <Transition
          as={Fragment}
          enter="transition ease-out duration-100"
          enterFrom="transform opacity-0 scale-95"
          enterTo="transform opacity-100 scale-100"
          leave="transition ease-in duration-75"
          leaveFrom="transform opacity-100 scale-100"
          leaveTo="transform opacity-0 scale-95">
          <Menu.Items className="py-1 text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10" static>
            { renderItem({ label: "Disabled", value: false, isCurrentlySelected: !query.comparison }) }
            { Object.keys(COMPARISON_MODES).map((key) => renderItem({ label: COMPARISON_MODES[key], value: key, isCurrentlySelected: key == query.comparison})) }
          </Menu.Items>
        </Transition>
      </Menu>
    </div>
    </div>
  )
}

export default withRouter(ComparisonInput)
