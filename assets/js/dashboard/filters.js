import React, { Fragment, useEffect, useState } from 'react';
import { Link, withRouter } from 'react-router-dom';
import { AdjustmentsVerticalIcon, MagnifyingGlassIcon, XMarkIcon, PencilSquareIcon } from '@heroicons/react/20/solid';
import classNames from 'classnames';
import { Menu, Transition } from '@headlessui/react';

import { navigateToQuery } from './query';
import {
  FILTER_GROUP_TO_MODAL_TYPE,
  cleanLabels,
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup,
  formattedFilters,
  EVENT_PROPS_PREFIX,
  getPropertyKeyFromFilterKey,
  getLabel,
  FILTER_OPERATIONS_DISPLAY_NAMES
} from "./util/filters";
import { useQueryContext } from './query-context';
import { useSiteContext } from './site-context';

const WRAPSTATE = { unwrapped: 0, waiting: 1, wrapped: 2 }

function removeFilter(filterIndex, history, query) {
  const newFilters = query.filters.filter((_filter, index) => filterIndex != index)
  const newLabels = cleanLabels(newFilters, query.labels)

  navigateToQuery(
    history,
    query,
    { filters: newFilters, labels: newLabels }
  )
}

function clearAllFilters(history, query) {
  navigateToQuery(
    history,
    query,
    { filters: false, labels: false }
  );
}

function plainFilterText(query, [operation, filterKey, clauses]) {
  const formattedFilter = formattedFilters[filterKey]

  if (formattedFilter) {
    return `${formattedFilter} ${FILTER_OPERATIONS_DISPLAY_NAMES[operation]} ${clauses.map((value) => getLabel(query.labels, filterKey, value)).reduce((prev, curr) => `${prev} or ${curr}`)}`
  } else if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return `Property ${propKey} ${FILTER_OPERATIONS_DISPLAY_NAMES[operation]} ${clauses.reduce((prev, curr) => `${prev} or ${curr}`)}`
  }

  throw new Error(`Unknown filter: ${filterKey}`)
}

function styledFilterText(query, [operation, filterKey, clauses]) {
  const formattedFilter = formattedFilters[filterKey]

  if (formattedFilter) {
    return <>{formattedFilter} {FILTER_OPERATIONS_DISPLAY_NAMES[operation]} {clauses.map((value) => <b key={value}>{getLabel(query.labels, filterKey, value)}</b>).reduce((prev, curr) => [prev, ' or ', curr])} </>
  } else if (filterKey.startsWith(EVENT_PROPS_PREFIX)) {
    const propKey = getPropertyKeyFromFilterKey(filterKey)
    return <>Property <b>{propKey}</b> {FILTER_OPERATIONS_DISPLAY_NAMES[operation]} {clauses.map((label) => <b key={label}>{label}</b>).reduce((prev, curr) => [prev, ' or ', curr])} </>
  }

  throw new Error(`Unknown filter: ${filterKey}`)
}

function renderDropdownFilter(filterIndex, filter, site, history, query) {
  const [_operation, filterKey, _clauses] = filter

  const type = filterKey.startsWith(EVENT_PROPS_PREFIX) ? 'props' : filterKey
  return (
    <Menu.Item key={filterIndex}>
      <div className="px-3 md:px-4 sm:py-2 py-3 text-sm leading-tight flex items-center justify-between" key={filterIndex}>
        <Link
          title={`Edit filter: ${plainFilterText(query, filter)}`}
          to={{ pathname: `/filter/${FILTER_GROUP_TO_MODAL_TYPE[type]}`, search: window.location.search }}
          className="group flex w-full justify-between items-center"
          style={{ width: 'calc(100% - 1.5rem)' }}
        >
          <span className="inline-block w-full truncate">{styledFilterText(query, filter)}</span>
          <PencilSquareIcon className="w-4 h-4 ml-1 cursor-pointer group-hover:text-indigo-700 dark:group-hover:text-indigo-500" />
        </Link>
        <b
          title={`Remove filter: ${plainFilterText(query, filter)}`}
          className="ml-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500"
          onClick={() => removeFilter(filterIndex, history, query)}
        >
          <XMarkIcon className="w-4 h-4" />
        </b>
      </div>
    </Menu.Item>
  )
}

function filterDropdownOption(site, option) {
  return (
    <Menu.Item key={option}>
      {({ active }) => (
        <Link
          to={{ pathname: `/filter/${option}`, search: window.location.search }}
          className={classNames(
            active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100' : 'text-gray-800 dark:text-gray-300',
            'block px-4 py-2 text-sm font-medium'
          )}
        >
          {formatFilterGroup(option)}
        </Link>
      )}
    </Menu.Item>
  )
}

function DropdownContent({ history, wrapped }) {
  const site = useSiteContext();
  const { query } = useQueryContext();
  const [addingFilter, setAddingFilter] = useState(false);

  if (wrapped === WRAPSTATE.unwrapped || addingFilter) {
    let filterModals = { ...FILTER_MODAL_TO_FILTER_GROUP }
    if (!site.propsAvailable) delete filterModals.props

    return Object.keys(filterModals).map((option) => filterDropdownOption(site, option))
  }

  return (
    <>
      <div className="border-b border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer" onClick={() => setAddingFilter(true)}>
        + Add filter
      </div>
      {query.filters.map((filter, index) => renderDropdownFilter(index, filter, site, history, query))}
      <Menu.Item key="clear">
        <div className="border-t border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer" onClick={() => clearAllFilters(history, query)}>
          Clear All Filters
        </div>
      </Menu.Item>
    </>
  )
}

function Filters({ history }) {
  const { query } = useQueryContext();

  const [wrapped, setWrapped] = useState(WRAPSTATE.waiting)
  const [viewport, setViewport] = useState(1080)

  useEffect(() => {
    handleResize()

    window.addEventListener('resize', handleResize, false)
    document.addEventListener('keyup', handleKeyup)

    return () => {
      window.removeEventListener('resize', handleResize, false)
      document.removeEventListener("keyup", handleKeyup)
    }
  }, [])

  useEffect(() => {
    setWrapped(WRAPSTATE.waiting)
  }, [query, viewport])

  useEffect(() => {
    if (wrapped === WRAPSTATE.waiting) { updateDisplayMode() }
  }, [wrapped])


  function handleKeyup(e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return

    if (e.key === 'Escape') {
      clearAllFilters(history, query)
    }
  }

  function handleResize() {
    setViewport(window.innerWidth || 639)
  }

  // Checks if the filter container is wrapping items
  function updateDisplayMode() {
    const container = document.getElementById('filters')
    const children = container && [...container.childNodes] || []

    // Always wrap on mobile
    if (query.filters.length > 0 && viewport <= 768) {
      setWrapped(WRAPSTATE.wrapped)
      return
    }

    setWrapped(WRAPSTATE.unwrapped)

    // Check for different y value between all child nodes - this indicates a wrap
    children.forEach(child => {
      const currentChildY = child.getBoundingClientRect().top
      const firstChildY = children[0].getBoundingClientRect().top
      if (currentChildY !== firstChildY) {
        setWrapped(WRAPSTATE.wrapped)
      }
    })
  }

  function renderListFilter(filterIndex, filter) {
    const [_operation, filterKey, _clauses] = filter
    const type = filterKey.startsWith(EVENT_PROPS_PREFIX) ? 'props' : filterKey
    return (
      <span key={filterIndex} className="flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded mr-2 items-center">
        <Link
          title={`Edit filter: ${plainFilterText(query, filter)}`}
          className="flex w-full h-full items-center py-2 pl-3"
          to={{
            pathname: `/filter/${FILTER_GROUP_TO_MODAL_TYPE[type]}`,
            search: window.location.search
          }}
        >

          <span className="inline-block max-w-2xs md:max-w-xs truncate">{styledFilterText(query, filter)}</span>
        </Link>
        <span
          title={`Remove filter: ${plainFilterText(query, filter)}`}
          className="flex h-full w-full px-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 items-center"
          onClick={() => removeFilter(filterIndex, history, query)}
        >
          <XMarkIcon className="w-4 h-4" />
        </span>
      </span>
    )
  }

  function renderDropdownButton() {
    if (wrapped === WRAPSTATE.wrapped) {
      const filterCount = query.filters.length
      return (
        <>
          <AdjustmentsVerticalIcon className="-ml-1 mr-1 h-4 w-4" aria-hidden="true" />
          {filterCount} Filter{filterCount === 1 ? '' : 's'}
        </>
      )
    }

    return (
      <>
        <MagnifyingGlassIcon className="-ml-1 mr-1 h-4 w-4 md:h-4 md:w-4" aria-hidden="true" />
        {/* This would have been a good use-case for JSX! But in the interest of keeping the breakpoint width logic with TailwindCSS, this is a better long-term way to deal with it. */}
        <span className="sm:hidden">Filter</span><span className="hidden sm:inline-block">Filter</span>
      </>
    )
  }

  function trackFilterMenu() {
    window.trackCustomEvent('Filter Menu: Open')
  }

  function renderDropDown() {
    return (
      <Menu as="div" className="md:relative ml-auto">
        {({ open }) => (
          <>
            <div>
              <Menu.Button onClick={trackFilterMenu} className="flex items-center text-xs md:text-sm font-medium leading-tight px-3 py-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded">
                {renderDropdownButton()}
              </Menu.Button>
            </div>

            <Transition
              show={open}
              as={Fragment}
              enter="transition ease-out duration-100"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="transition ease-in duration-75"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Menu.Items
                static
                className="absolute w-full left-0 right-0 md:w-72 md:absolute md:top-auto md:left-auto md:right-0 mt-2 origin-top-right z-10"
              >
                <div
                  className="rounded-md shadow-lg  bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5
                  font-medium text-gray-800 dark:text-gray-200"
                >
                  <DropdownContent history={history} wrapped={wrapped} />
                </div>
              </Menu.Items>
            </Transition>
          </>
        )}
      </Menu>
    );
  }

  function renderFilterList() {
    // The filters are rendered even when `wrapped === WRAPSTATE.waiting`.
    // Otherwise, if they don't exist in the DOM, we can't check whether
    // the flex-wrap is actually putting them on multiple lines.
    if (wrapped !== WRAPSTATE.wrapped) {
      return (
        <div id="filters" className="flex flex-wrap">
          {query.filters.map((filter, index) => renderListFilter(index, filter))}
        </div>
      )
    }

    return null
  }

  return (
    <>
      {renderFilterList()}
      {renderDropDown()}
    </>
  )
}

export default withRouter(Filters);
