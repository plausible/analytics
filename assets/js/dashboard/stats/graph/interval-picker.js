import { Menu, Transition } from '@headlessui/react';
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import React, { Component, Fragment } from 'react';
import classNames from 'classnames'

export const INTERVAL_LABELS = {
  'minute': 'Minutes',
  'hour': 'Hours',
  'date': 'Days',
  'week': 'Weeks',
  'month': 'Months'
}

export default class IntervalPicker extends Component {
  constructor(props) {
    super(props)
    this.renderDropdownOption = this.renderDropdownOption.bind(this)
  }

  render() {
    if (this.props.query.period == 'realtime') return null

    const currentInterval = this.props.graphData?.interval || this.props.query.interval || "all"
    let possibleIntervals = this.props.site.allowedIntervalsForPeriod[this.props.query.period]
    possibleIntervals = possibleIntervals.filter(interval => interval !== currentInterval)

    return (
      <Menu as="div" className="relative inline-block">
        <Menu.Button className="inline-flex focus:outline-none text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600 items-center">
          { INTERVAL_LABELS[currentInterval] }
          <ChevronDownIcon className="h-5 w-5" aria-hidden="true" />
        </Menu.Button>

        <Menu.Items className="py-1 text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10">
          { possibleIntervals.map(this.renderDropdownOption) }
        </Menu.Items>
      </Menu>
    )
  }

  renderDropdownOption(interval) {
    return (
      <Menu.Item onClick={() => { this.props.updateInterval(interval) }} key={interval}>
        {({ active }) => (
          <span
            className={classNames(
              active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer' : 'text-gray-700 dark:text-gray-200',
              'block px-4 py-2 text-sm'
            )}
          >
            { INTERVAL_LABELS[interval] }
          </span>
        )}
      </Menu.Item>
    )
  }
}
