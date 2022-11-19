import { Menu } from '@headlessui/react';
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import React, { Component } from 'react';
import classNames from 'classnames'
import * as storage from '../../util/storage'

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

function DropdownItem({ option, currentInterval, updateInterval }) {
  return (
    <Menu.Item onClick={() => updateInterval(option)} key={option}>
      {({ active }) => (
        <span className={classNames({
                'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer': active,
                'text-gray-700 dark:text-gray-200': !active,
                'font-bold': option == currentInterval,
              }, 'block px-4 py-2 text-sm')}>
          { INTERVAL_LABELS[option] }
        </span>
      )}
    </Menu.Item>
  )
}

export function IntervalPicker({ graphData, query, site, updateInterval }) {
  if (query.period == 'realtime') return null

  const currentInterval = graphData?.interval || query.interval || "all"
  const options = site.allowedIntervalsForPeriod[query.period]

  return (
    <Menu as="div" className="relative inline-block">
      <Menu.Button className="inline-flex focus:outline-none text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600 items-center">
        { INTERVAL_LABELS[currentInterval] }
        <ChevronDownIcon className="h-5 w-5" aria-hidden="true" />
      </Menu.Button>

      <Menu.Items className="py-1 text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10">
        { options.map((option) => DropdownItem({ option, currentInterval, updateInterval })) }
      </Menu.Items>
    </Menu>
  )
}
