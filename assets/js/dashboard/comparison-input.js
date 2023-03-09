import React, { Fragment } from 'react'
import { withRouter } from "react-router-dom";
import { navigateToQuery } from './query'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from './util/storage'
import { parseUTCDate, formatDayShort } from "./util/date"

const COMPARISON_MODES = {
  'previous_period': 'Previous period',
  'year_over_year': 'Year over year',
}

export const COMPARISON_DISABLED_PERIODS = ['realtime', 'all']

export const getStoredComparisonMode = function(domain) {
  const mode = storage.getItem(`comparison_mode__${domain}`)
  if (Object.keys(COMPARISON_MODES).includes(mode)) {
    return mode
  } else {
    return null
  }
}

const storeComparisonMode = function(domain, mode) {
  storage.setItem(`comparison_mode__${domain}`, mode)
}

export const toggleComparisons = function(history, query, site) {
  if (!site.flags.comparisons) return
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return

  const defaultMode = getStoredComparisonMode(site.domain) || 'previous_period'
  const toggle = query.comparison ? false : defaultMode
  storeComparisonMode(site.domain, toggle)

  navigateToQuery(history, query, { comparison: toggle })
}

function DropdownItem({ label, value, isCurrentlySelected, updateMode }) {
  return (
    <Menu.Item
      key={value}
      onClick={() => updateMode(value)}
      disabled={isCurrentlySelected}>
      {({ active }) => (
        <button className={classNames("px-4 py-2 w-full text-left font-medium text-sm dark:text-white cursor-pointer", { "bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100": active, "font-bold": isCurrentlySelected })}>
          { label }
        </button>
      )}
    </Menu.Item>
  )
}

const ComparisonInput = function({ site, query, history, graphData }) {
  if (!site.flags.comparisons) return null
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return null
  if (!query.comparison) return null

  const updateMode = (key) => {
    storeComparisonMode(site.domain, key)
    navigateToQuery(history, query, { comparison: key })
  }

  const buildLabel = () => {
    if (!graphData || !graphData.comparison_labels) return null

    const sourceFrom = parseUTCDate(graphData.labels.at(0))
    const comparingFrom = parseUTCDate(graphData.comparison_labels.at(0))
    const comparingTo = parseUTCDate(graphData.comparison_labels.at(-1))

    const comparisonDatesCrossYearBoundary = comparingFrom.getYear() !== comparingTo.getYear()
    const comparingDifferentYears = sourceFrom.getYear() != comparingFrom.getYear()

    return `${formatDayShort(comparingFrom, comparisonDatesCrossYearBoundary)} - ${formatDayShort(comparingTo, comparingDifferentYears || comparisonDatesCrossYearBoundary)}`
  }

  return (
    <>
      <span className="pl-2 text-sm font-medium text-gray-800 dark:text-gray-200">vs.</span>
      <div className="flex">
        <div className="min-w-32 md:w-52 md:relative">
          <Menu as="div" className="relative inline-block pl-2 w-full">
            <Menu.Button className="bg-white text-gray-800 text-xs md:text-sm font-medium dark:bg-gray-800 dark:hover:bg-gray-900 dark:text-gray-200 hover:bg-gray-200 flex md:px-3 px-2 py-2 items-center justify-between leading-tight rounded shadow cursor-pointer w-full truncate">
              <span className="truncate">{ buildLabel() }</span>
              <ChevronDownIcon className="hidden sm:inline-block h-4 w-4 md:h-5 md:w-5 text-gray-500 ml-2" aria-hidden="true" />
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
                { DropdownItem({ label: "No comparison", value: false, isCurrentlySelected: !query.comparison, updateMode }) }
                { Object.keys(COMPARISON_MODES).map((key) => DropdownItem({ label: COMPARISON_MODES[key], value: key, isCurrentlySelected: key == query.comparison, updateMode })) }
              </Menu.Items>
            </Transition>
          </Menu>
        </div>
      </div>
    </>
  )
}

export default withRouter(ComparisonInput)
