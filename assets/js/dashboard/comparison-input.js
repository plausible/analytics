import React, { Fragment } from 'react'
import { withRouter } from 'react-router-dom'
import { navigateToQuery } from './query'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from './util/storage'
import Flatpickr from 'react-flatpickr'
import { formatISO, parseUTCDate, formatDayShort } from './util/date.js'

const COMPARISON_MODES = {
  'off': 'Disable comparison',
  'previous_period': 'Previous period',
  'year_over_year': 'Year over year',
  'custom': 'Custom period',
}

const DEFAULT_COMPARISON_MODE = 'previous_period'

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
  if (mode == "custom") return
  storage.setItem(`comparison_mode__${domain}`, mode)
}

export const isComparisonEnabled = function(mode) {
  return mode && mode !== "off"
}

export const toggleComparisons = function(history, query, site) {
  if (!site.flags.comparisons) return
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return

  if (isComparisonEnabled(query.comparison)) {
    storeComparisonMode(site.domain, "off")
    navigateToQuery(history, query, { comparison: "off" })
  } else {
    const storedMode = getStoredComparisonMode(site.domain)
    const newMode = isComparisonEnabled(storedMode) ? storedMode : DEFAULT_COMPARISON_MODE

    storeComparisonMode(site.domain, newMode)
    navigateToQuery(history, query, { comparison: newMode })
  }
}

function DropdownItem({ label, value, isCurrentlySelected, updateMode, setUiMode }) {
  const click = () => {
    if (value == "custom") {
      setUiMode("datepicker")
    } else {
      updateMode(value)
    }
  }

  const render = ({ active }) => {
    const buttonClass = classNames("px-4 py-2 w-full text-left font-medium text-sm dark:text-white cursor-pointer", {
      "bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100": active,
      "font-bold": isCurrentlySelected,
    })

    return <button className={buttonClass}>{ label }</button>
  }

  const disabled = isCurrentlySelected && value !== "custom"

  return (
    <Menu.Item key={value} onClick={click} disabled={disabled}>
      { render }
    </Menu.Item>
  )
}

const ComparisonInput = function({ site, query, history }) {
  if (!site.flags.comparisons) return null
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return null
  if (!isComparisonEnabled(query.comparison)) return null

  const updateMode = (mode, from = null, to = null) => {
    storeComparisonMode(site.domain, mode)
    navigateToQuery(history, query, { comparison: mode, compare_from: from, compare_to: to })
  }

  const buildLabel = (query) => {
    if (query.comparison == "custom") {
      const from = parseUTCDate(query.compare_from)
      const to = parseUTCDate(query.compare_to)
      return `${formatDayShort(from, false)} - ${formatDayShort(to, false)}`
    } else {
      return COMPARISON_MODES[query.comparison]
    }
  }

  const calendar = React.useRef(null)

  const [uiMode, setUiMode] = React.useState("menu")
  React.useEffect(() => {
    if (uiMode == "datepicker" && calendar) calendar.current.flatpickr.open()
  }, [uiMode])

  const flatpickrOptions = {
    mode: 'range',
    showMonths: 1,
    maxDate: 'today',
    minDate: parseUTCDate(site.statsBegin),
    animate: true,
    static: true,
    onClose: ([from, to], _dateStr, _instance) => {
      setUiMode("menu")
      if (from && to) updateMode("custom", formatISO(from), formatISO(to))
    }
  }

  return (
    <>
      <span className="pl-2 text-sm font-medium text-gray-800 dark:text-gray-200">vs.</span>
      <div className="flex">
        <div className="min-w-32 md:w-48 md:relative">
          <Menu as="div" className="relative inline-block pl-2 w-full">
            <Menu.Button className="bg-white text-gray-800 text-xs md:text-sm font-medium dark:bg-gray-800 dark:hover:bg-gray-900 dark:text-gray-200 hover:bg-gray-200 flex md:px-3 px-2 py-2 items-center justify-between leading-tight rounded shadow cursor-pointer w-full truncate">
              <span className="truncate">{ buildLabel(query) }</span>
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
                { Object.keys(COMPARISON_MODES).map((key) => DropdownItem({ label: COMPARISON_MODES[key], value: key, isCurrentlySelected: key == query.comparison, updateMode, setUiMode })) }
              </Menu.Items>
            </Transition>

            { uiMode == "datepicker" &&
            <div className="h-0 absolute">
              <Flatpickr ref={calendar} options={flatpickrOptions} className="invisible" />
            </div>
            }
          </Menu>
        </div>
      </div>
    </>
  )
}

export default withRouter(ComparisonInput)
