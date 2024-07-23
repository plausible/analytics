import React, { Fragment, useState, useRef, useEffect } from 'react'
import { navigateToQuery } from './query'
import { useNavigate } from '@tanstack/react-router'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from './util/storage'
import Flatpickr from 'react-flatpickr'
import { parseNaiveDate, formatISO, formatDateRange } from './util/date.js'
import { useQueryContext } from './query-context.js'
import { useSiteContext } from './site-context.js'

const COMPARISON_MODES = {
  'off': 'Disable comparison',
  'previous_period': 'Previous period',
  'year_over_year': 'Year over year',
  'custom': 'Custom period',
}

const DEFAULT_COMPARISON_MODE = 'previous_period'

export const COMPARISON_DISABLED_PERIODS = ['realtime', 'all']

const getMatchDayOfWeekStorageKey = (domain) => storage.getDomainScopedStorageKey('comparison_match_day_of_week', domain)

const storeMatchDayOfWeek = function (domain, matchDayOfWeek) {
  storage.setItem(getMatchDayOfWeekStorageKey(domain), matchDayOfWeek.toString());
}

export const getStoredMatchDayOfWeek = function (domain, fallbackValue) {
  const storedValue = storage.getItem(getMatchDayOfWeekStorageKey(domain));
  if (storedValue === 'true') {
    return true;
  } 
  if (storedValue === 'false') {
    return false;
  }
  return fallbackValue;
}

const getComparisonModeStorageKey = (domain) => storage.getDomainScopedStorageKey('comparison_mode', domain)
export const getStoredComparisonMode = function (domain, fallbackValue) {
  const storedValue = storage.getItem(getComparisonModeStorageKey(domain))
  if (Object.keys(COMPARISON_MODES).includes(storedValue)) {
    return storedValue
  } 
  
  return fallbackValue
}

const storeComparisonMode = function (domain, mode) {
  if (mode == "custom") return
  storage.setItem(getComparisonModeStorageKey(domain), mode)
}

export const isComparisonEnabled = function (mode) {
  return mode && mode !== "off"
}

export const toggleComparisons = function (navigate, query, site) {
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return

  if (isComparisonEnabled(query.comparison)) {
    storeComparisonMode(site.domain, "off")
    navigateToQuery(navigate, query, { comparison: "off" })
  } else {
    const storedMode = getStoredComparisonMode(site.domain, null)
    const newMode = isComparisonEnabled(storedMode) ? storedMode : DEFAULT_COMPARISON_MODE

    storeComparisonMode(site.domain, newMode)
    navigateToQuery(navigate, query, { comparison: newMode })
  }
}

function ComparisonModeOption({ label, value, isCurrentlySelected, updateMode, setUiMode }) {
  const click = () => {
    if (value == "custom") {
      setUiMode("datepicker")
    } else {
      updateMode(value)
    }
  }

  const render = ({ active }) => {
    const buttonClass = classNames("px-4 py-2 w-full text-left text-sm dark:text-white", {
      "bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100": active,
      "font-medium": !isCurrentlySelected,
      "font-bold": isCurrentlySelected,
    })

    return <button className={buttonClass}>{label}</button>
  }

  const disabled = isCurrentlySelected && value !== "custom"

  return (
    <Menu.Item key={value} onClick={click} disabled={disabled}>
      {render}
    </Menu.Item>
  )
}

function MatchDayOfWeekInput() {
  const navigate = useNavigate();
  const site = useSiteContext()
  const { query } = useQueryContext()
  const click = (matchDayOfWeek) => {
    storeMatchDayOfWeek(site.domain, matchDayOfWeek)
    navigateToQuery(navigate, query, { match_day_of_week: matchDayOfWeek })
  }

  const buttonClass = (hover, selected) =>
    classNames("px-4 py-2 w-full text-left text-sm dark:text-white cursor-pointer", {
      "bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100": hover,
      "font-medium": !selected,
      "font-bold": selected,
    })

  return <>
    <Menu.Item key="match_day_of_week" onClick={() => click(true)}>
      {({ active }) => (
        <button className={buttonClass(active, query.match_day_of_week)}>Match day of the week</button>
      )}
    </Menu.Item>

    <Menu.Item key="match_exact_date" onClick={() => click(false)}>
      {({ active }) => (
        <button className={buttonClass(active, !query.match_day_of_week)}>Match exact date</button>
      )}
    </Menu.Item>
  </>
}

const ComparisonInput = function ({ navigate }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

  const calendar = useRef(null)

  const [uiMode, setUiMode] = useState("menu")

  useEffect(() => {
    if (uiMode == "datepicker") {
      setTimeout(() => calendar.current.flatpickr.open(), 100)
    }
  }, [uiMode])
  
  if (COMPARISON_DISABLED_PERIODS.includes(query.period)) return null
  if (!isComparisonEnabled(query.comparison)) return null

  const updateMode = (mode, from = null, to = null) => {
    storeComparisonMode(site.domain, mode)
    navigateToQuery(navigate, query, { comparison: mode, compare_from: from, compare_to: to })
  }

  const buildLabel = (site, query) => {
    if (query.comparison == "custom") {
      return formatDateRange(site, query.compare_from, query.compare_to)
    } else {
      return COMPARISON_MODES[query.comparison]
    }
  }

  const flatpickrOptions = {
    mode: 'range',
    showMonths: 1,
    maxDate: 'today',
    minDate: site.statsBegin,
    animate: true,
    static: true,
    onClose: ([from, to], _dateStr, _instance) => {
      setUiMode("menu")

      if (from && to) {
        [from, to] = [parseNaiveDate(from), parseNaiveDate(to)]
        updateMode("custom", formatISO(from), formatISO(to))
      }
    }
  }

  return (
    <>
      <span className="hidden md:block pl-2 text-sm font-medium text-gray-800 dark:text-gray-200">vs.</span>
      <div className="flex">
        <div className="min-w-32 md:w-48 md:relative">
          <Menu as="div" className="relative inline-block pl-2 w-full">
            <Menu.Button className="bg-white text-gray-800 text-xs md:text-sm font-medium dark:bg-gray-800 dark:hover:bg-gray-900 dark:text-gray-200 hover:bg-gray-200 flex md:px-3 px-2 py-2 items-center justify-between leading-tight rounded shadow cursor-pointer w-full truncate">
              <span className="truncate">{buildLabel(site, query)}</span>
              <ChevronDownIcon className="hidden sm:inline-block h-4 w-4 md:h-5 md:w-5 text-gray-500 ml-2" aria-hidden="true" />
            </Menu.Button>
            <Transition
              as={Fragment}
              enter="transition ease-out duration-100"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="transition ease-in duration-75"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95">
              <Menu.Items className="py-1 text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10" static>
                {Object.keys(COMPARISON_MODES).map((key) => ComparisonModeOption({ label: COMPARISON_MODES[key], value: key, isCurrentlySelected: key == query.comparison, updateMode, setUiMode }))}
                {query.comparison !== "custom" && <span>
                  <hr className="my-1" />
                  <MatchDayOfWeekInput />
                </span>}
              </Menu.Items>
            </Transition>

            {uiMode == "datepicker" &&
              <div className="h-0 md:absolute">
                <Flatpickr ref={calendar} options={flatpickrOptions} className="invisible" />
              </div>}
          </Menu>
        </div>
      </div>
    </>
  )
}

export default function ComparisonInputWrapped(props) {const navigate = useNavigate(); return <ComparisonInput {...props} navigate={navigate}/>}
