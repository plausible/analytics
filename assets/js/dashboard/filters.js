import React, { Fragment, useEffect, useState } from 'react';
import { useQueryContext } from './query-context';
import { useSiteContext } from './site-context';
import { filterRoute } from './router';
import { AppNavigationLink, useAppNavigate } from './navigation/use-app-navigate';
import { AdjustmentsVerticalIcon, MagnifyingGlassIcon, XMarkIcon, PencilSquareIcon } from '@heroicons/react/20/solid';
import classNames from 'classnames';
import { Menu, Transition } from '@headlessui/react';

import {
  FILTER_GROUP_TO_MODAL_TYPE,
  cleanLabels,
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup,
  EVENT_PROPS_PREFIX
} from "./util/filters"
import { plainFilterText, styledFilterText } from "./util/filter-text"

const WRAPSTATE = { unwrapped: 0, waiting: 1, wrapped: 2 }

function removeFilter(filterIndex, navigate, query) {
  const newFilters = query.filters.filter((_filter, index) => filterIndex != index)
  const newLabels = cleanLabels(newFilters, query.labels)

  navigate({
    search: (search) => ({
      ...search,
      filters: newFilters,
      labels: newLabels
    })
  })
}

function clearAllFilters(navigate) {
  navigate({
    search: (search) => ({
      ...search,
      filters: null,
      labels: null
    })
  })
}

function AppliedFilterPillVertical({filterIndex, filter}) {
  const { query } = useQueryContext();
  const navigate = useAppNavigate();
  const [_operation, filterKey, _clauses] = filter

  const type = filterKey.startsWith(EVENT_PROPS_PREFIX) ? 'props' : filterKey

  return (
    <Menu.Item key={filterIndex}>
      <div className="px-3 md:px-4 sm:py-2 py-3 text-sm leading-tight flex items-center justify-between" key={filterIndex}>
        <AppNavigationLink
          title={`Edit filter: ${plainFilterText(query, filter)}`}
          path={filterRoute.path}
          params={{field: FILTER_GROUP_TO_MODAL_TYPE[type]}}
          search={(search) => search}
          className="group flex w-full justify-between items-center"
          style={{ width: 'calc(100% - 1.5rem)' }}
        >
          <span className="inline-block w-full truncate">{styledFilterText(query, filter)}</span>
          <PencilSquareIcon className="w-4 h-4 ml-1 cursor-pointer group-hover:text-indigo-700 dark:group-hover:text-indigo-500" />
        </AppNavigationLink>
        <b
          title={`Remove filter: ${plainFilterText(query, filter)}`}
          className="ml-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500"
          onClick={() => removeFilter(filterIndex, navigate, query)}
        >
          <XMarkIcon className="w-4 h-4" />
        </b>
      </div>
    </Menu.Item>
  )
}

function OpenFilterGroupOptionsButton({option}) {
  return (
    <Menu.Item>
      {({ active }) => (
        <AppNavigationLink
          path={filterRoute.path}
          params={{field: option}}
          search={(search) => search}
          className={classNames(
            active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100' : 'text-gray-800 dark:text-gray-300',
            'block px-4 py-2 text-sm font-medium'
          )}
        >
          {formatFilterGroup(option)}
        </AppNavigationLink>
      )}
    </Menu.Item>
  )
}

function DropdownContent({ wrapped }) {
  const navigate = useAppNavigate();
  const site = useSiteContext();
  const { query } = useQueryContext();
  const [addingFilter, setAddingFilter] = useState(false);

  if (wrapped === WRAPSTATE.unwrapped || addingFilter) {
    let filterModals = { ...FILTER_MODAL_TO_FILTER_GROUP }
    if (!site.propsAvailable) delete filterModals.props

    return <>{Object.keys(filterModals).map((option) => <OpenFilterGroupOptionsButton key={option} option={option} />)}</>
  }

  return (
    <>
      <div className="border-b border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer" onClick={() => setAddingFilter(true)}>
        + Add filter
      </div>
      {query.filters.map((filter, index) => <AppliedFilterPillVertical key={index} filterIndex={index} filter={filter}/>)}
      <Menu.Item key="clear">
        <div className="border-t border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer" onClick={() => clearAllFilters(navigate)}>
          Clear All Filters
        </div>
      </Menu.Item>
    </>
  )
}

function Filters() {
  const navigate = useAppNavigate();
  const { query } = useQueryContext();

  const [wrapped, setWrapped] = useState(WRAPSTATE.waiting)
  const [viewport, setViewport] = useState(1080)

  useEffect(() => {
    handleResize()

    window.addEventListener('resize', handleResize, false)

    return () => {
      window.removeEventListener('resize', handleResize, false)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    setWrapped(WRAPSTATE.waiting)
  }, [query, viewport])

  useEffect(() => {
    if (wrapped === WRAPSTATE.waiting) { updateDisplayMode() }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wrapped])

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

  function AppliedFilterPillHorizontal({filterIndex, filter}) {
    const { query } = useQueryContext();
    const [_operation, filterKey, _clauses] = filter
    const type = filterKey.startsWith(EVENT_PROPS_PREFIX) ? 'props' : filterKey
    return (
      <span className="flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded mr-2 items-center">
        <AppNavigationLink
          title={`Edit filter: ${plainFilterText(query, filter)}`}
          className="flex w-full h-full items-center py-2 pl-3"
          path={filterRoute.path}
          params={{field: FILTER_GROUP_TO_MODAL_TYPE[type]}}
          search={(search)=> search}
        >
          <span className="inline-block max-w-2xs md:max-w-xs truncate">{styledFilterText(query, filter)}</span>
        </AppNavigationLink>
        <span
          title={`Remove filter: ${plainFilterText(query, filter)}`}
          className="flex h-full w-full px-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 items-center"
          onClick={() => removeFilter(filterIndex, navigate, query)}
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
          <AdjustmentsVerticalIcon className="-ml-1 mr-1 h-4 w-4 shrink-0" aria-hidden="true" />
          {filterCount} Filter{filterCount === 1 ? '' : 's'}
        </>
      )
    }

    return (
      <>
        <MagnifyingGlassIcon className="-ml-1 mr-1 h-4 w-4 shrink-0" aria-hidden="true" />
        {/* This would have been a good use-case for JSX! But in the interest of keeping the breakpoint width logic with TailwindCSS, this is a better long-term way to deal with it. */}
        <span className="sm:hidden">Filter</span><span className="hidden sm:inline-block">Filter</span>
      </>
    )
  }

  function trackFilterMenu() {
    if (window.trackCustomEvent) {
      window.trackCustomEvent('Filter Menu: Open')
    }
  }

  function renderDropDown() {
    return (
      <Menu as="div" className="md:relative ml-auto shrink-0">
        {({ open }) => (
          <>
            <div>
              <Menu.Button onClick={trackFilterMenu} className="flex items-center text-xs md:text-sm font-medium leading-tight px-3 py-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded whitespace-nowrap w-fit">
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
                  <DropdownContent wrapped={wrapped} />
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
          {query.filters.map((filter, index) => <AppliedFilterPillHorizontal key={index} filterIndex={index} filter={filter} />)}
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

export default Filters;
