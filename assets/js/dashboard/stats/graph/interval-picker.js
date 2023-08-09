import { Menu, Transition } from '@headlessui/react';
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import React, { Fragment, useCallback, useEffect } from 'react';
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { isKeyPressed } from '../../keybinding.js'
import { monthsBetweenDates } from '../../util/date.js'

export const INTERVAL_LABELS = {
  'minute': 'Minutes',
  'hour': 'Hours',
  'date': 'Days',
  'week': 'Weeks',
  'month': 'Months'
}

export const getStoredInterval = function(period, domain) {
  return storage.getItem(`interval__${period}__${domain}`)
}

export const storeInterval = function(period, domain, interval) {
  storage.setItem(`interval__${period}__${domain}`, interval)
}

function subscribeKeybinding(element) {
  const handleKeyPress = useCallback((event) => {
    if (isKeyPressed(event, "i")) element.current?.click()
  }, [])

  useEffect(() => {
    document.addEventListener('keydown', handleKeyPress)
    return () => document.removeEventListener('keydown', handleKeyPress)
  }, [handleKeyPress])
}

function DropdownItem({ option, currentInterval, updateInterval }) {
  return (
    <Menu.Item onClick={() => updateInterval(option)} key={option} disabled={option == currentInterval}>
      {({ active }) => (
        <span className={classNames({
          'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer': active,
          'text-gray-700 dark:text-gray-200': !active,
          'font-bold cursor-none select-none': option == currentInterval,
        }, 'block px-4 py-2 text-sm')}>
          {INTERVAL_LABELS[option]}
        </span>
      )}
    </Menu.Item>
  )
}

export function IntervalPicker({ graphData, query, site, updateInterval }) {
  if (query.period == 'realtime') return null

  const menuElement = React.useRef(null)
  subscribeKeybinding(menuElement)

  let currentInterval = graphData?.interval

  let options = site.validIntervalsByPeriod[query.period]
  if (query.period === "custom" && monthsBetweenDates(query.from, query.to) > 12) {
    options = ["week", "month"]
  }

  if (!options.includes(currentInterval)) {
    currentInterval = [...options].pop()
  }

  return (
    <Menu as="div" className="relative inline-block pl-2">
      {({ open }) => (
        <>
          <Menu.Button ref={menuElement} className="text-sm inline-flex focus:outline-none text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600 items-center">
            {INTERVAL_LABELS[currentInterval]}
            <ChevronDownIcon className="ml-1 h-4 w-4" aria-hidden="true" />
          </Menu.Button>

          <Transition
            as={Fragment}
            show={open}
            enter="transition ease-out duration-100"
            enterFrom="transform opacity-0 scale-95"
            enterTo="transform opacity-100 scale-100"
            leave="transition ease-in duration-75"
            leaveFrom="transform opacity-100 scale-100"
            leaveTo="transform opacity-0 scale-95">
            <Menu.Items className="py-1 text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10" static>
              {options.map((option) => DropdownItem({ option, currentInterval, updateInterval }))}
            </Menu.Items>
          </Transition>
        </>
      )}
    </Menu>
  )
}
