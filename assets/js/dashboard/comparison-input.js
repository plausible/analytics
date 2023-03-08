import React, { Fragment, useEffect, useCallback } from 'react'
import { withRouter } from "react-router-dom";
import { navigateToQuery } from './query'
import { Menu, Transition } from '@headlessui/react'
import { ArrowsUpDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { isKeyPressed } from './keybinding'

const COMPARISON_MODES = {
  'previous_period': 'Previous period',
  'year_over_year': 'Year over year',
}

export const COMPARISON_DISABLED_PERIODS = ['realtime', 'all']

function subscribeKeybinding(element) {
  const handleKeyPress = useCallback((event) => {
    if (isKeyPressed(event, "x")) element.current?.click()
  }, [])

  useEffect(() => {
    document.addEventListener('keydown', handleKeyPress)
    return () => document.removeEventListener('keydown', handleKeyPress)
  }, [handleKeyPress])
}

const ComparisonInput = function({ site, query, history }) {
  if (!site.flags.comparisons) return null
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return null

  function update(key) {
    navigateToQuery(history, query, { comparison: key })
  }

  function renderItem({ label, value, isCurrentlySelected }) {
    return (
      <Menu.Item
        key={value}
        onClick={() => update(value)}
        disabled={isCurrentlySelected}>
        {({ active }) => (
          <button className={classNames("px-4 py-2 w-full text-left font-medium text-sm dark:text-white cursor-pointer", { "bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100": active, "font-bold": isCurrentlySelected })}>
            { label }
          </button>
        )}
      </Menu.Item>
    )
  }

  const element = React.useRef(null)
  subscribeKeybinding(element)

  return (
    <Menu as="div" className="relative">
      <Menu.Button ref={element} className="flex items-center text-xs md:text-sm font-medium leading-tight px-3 py-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded">
        <ArrowsUpDownIcon className="-ml-1 mr-1 h-4 w-4" aria-hidden="true" />
        <span>{ COMPARISON_MODES[query.comparison] || 'Compare to' }</span>
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
  )
}

export default withRouter(ComparisonInput)
