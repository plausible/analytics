import React, { Fragment, useState } from 'react';
import { Link, withRouter } from 'react-router-dom'
import { AdjustmentsVerticalIcon, MagnifyingGlassIcon, XMarkIcon, PencilSquareIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { Menu, Transition } from '@headlessui/react'

import { navigateToQuery } from './query'
import {
  FILTER_GROUPS,
  formatFilterGroup,
  filterGroupForFilter,
  formattedFilters
} from "./util/filters"

function removeFilter(filterIndex, history, query) {
  const newFilters = query.filters.filter((_filter, index) => filterIndex != index)

  navigateToQuery(
    history,
    query,
    { filters: newFilters.length > 0 ? newFilters : false }
  )
}

function clearAllFilters(history, query) {
  navigateToQuery(
    history,
    query,
    { filters: false }
  );
}

function filterText([operation, filterKey, clauses]) {
  const formattedFilter = formattedFilters[filterKey]

  // if (filterType === "props") {
  //   const { propKey, clauses, type } = parseQueryPropsFilter(query).find((filter) => filter.propKey.value === key)
  //   return <>Property <b>{propKey.label}</b> {type} {clauses.map(({label}) => <b key={label}>{label}</b>).reduce((prev, curr) => [prev, ' or ', curr])} </>
  // } else
  if (formattedFilter) {
    // :TODO: Labels support
    return <>{formattedFilter} {operation} {clauses.map((label) => <b key={label}>{label}</b>).reduce((prev, curr) => [prev, ' or ', curr])} </>
  }

  throw new Error(`Unknown filter: ${filterKey}`)
}

function renderDropdownFilter(filterIndex, filter, site, history, query) {
  const [_operation, filterKey, _clauses] = filter
  return (
    <Menu.Item key={filterIndex}>
      <div className="px-3 md:px-4 sm:py-2 py-3 text-sm leading-tight flex items-center justify-between" key={filterIndex}>
        <Link
          title={`Edit filter: ${formattedFilters[filterKey]}`}
          to={{ pathname: `/${encodeURIComponent(site.domain)}/filter/${filterGroupForFilter(filterKey)}`, search: window.location.search }}
          className="group flex w-full justify-between items-center"
          style={{ width: 'calc(100% - 1.5rem)' }}
        >
          <span className="inline-block w-full truncate">{filterText(filter)}</span>
          <PencilSquareIcon className="w-4 h-4 ml-1 cursor-pointer group-hover:text-indigo-700 dark:group-hover:text-indigo-500" />
        </Link>
        <b
          title={`Remove filter: ${formattedFilters[filterKey]}`}
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
          to={{ pathname: `/${encodeURIComponent(site.domain)}/filter/${option}`, search: window.location.search }}
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

function DropdownContent({ history, site, query, wrapped }) {
  const [addingFilter, setAddingFilter] = useState(false);

  if (wrapped === 0 || addingFilter) {
    let filterGroups = {...FILTER_GROUPS}
    if (!site.propsAvailable) delete filterGroups.props

    return Object.keys(filterGroups).map((option) => filterDropdownOption(site, option))
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

class Filters extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      wrapped: 1, // 0=unwrapped, 1=waiting to check, 2=wrapped
      viewport: 1080,
    };

    this.renderDropDown = this.renderDropDown.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.handleKeyup = this.handleKeyup.bind(this)
  }

  componentDidMount() {
    document.addEventListener('mousedown', this.handleClick, false);
    window.addEventListener('resize', this.handleResize, false);
    document.addEventListener('keyup', this.handleKeyup);

    this.handleResize();
    this.rewrapFilters();
  }

  componentDidUpdate(prevProps, prevState) {
    const { query } = this.props;
    const { viewport, wrapped } = this.state;

    if (JSON.stringify(query) !== JSON.stringify(prevProps.query) || viewport !== prevState.viewport) {
      // eslint-disable-next-line react/no-did-update-set-state
      this.setState({ wrapped: 1 });
    }

    if (wrapped === 1 && prevState.wrapped !== 1) {
      this.rewrapFilters();
    }
  }

  componentWillUnmount() {
    document.removeEventListener("keyup", this.handleKeyup);
    document.removeEventListener('mousedown', this.handleClick, false);
    window.removeEventListener('resize', this.handleResize, false);
  }

  handleKeyup(e) {
    const { query, history } = this.props

    if (e.ctrlKey || e.metaKey || e.altKey) return

    if (e.key === 'Escape') {
      clearAllFilters(history, query)
    }
  }

  handleResize() {
    this.setState({ viewport: window.innerWidth || 639 });
  }

  // Checks if the filter container is wrapping items
  rewrapFilters() {
    const items = document.getElementById('filters');
    const { wrapped, viewport } = this.state;

    // Always wrap on mobile
    if (this.props.query.filters.length > 0 && viewport <= 768) {
      this.setState({ wrapped: 2 })
      return;
    }

    this.setState({ wrapped: 0 });

    // Don't rewrap if we're already properly wrapped, there are no DOM children, or there is only filter
    if (wrapped !== 1 || !items || this.props.query.filters.length === 1) {
      return;
    };

    let prevItem = null;

    // For every filter DOM Node, check if its y value is higher than the previous (this indicates a wrap)
    [...(items.childNodes)].forEach(item => {
      const currItem = item.getBoundingClientRect();
      if (prevItem && prevItem.top < currItem.top) {
        this.setState({ wrapped: 2 });
      }
      prevItem = currItem;
    });
  };

  renderListFilter(filterIndex, filter, history, query) {
    const text = filterText(filter)
    const [_operation, filterKey, _clauses] = filter
    return (
      <span key={filterIndex} className="flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded mr-2 items-center">
        <Link
          title={`Edit filter: ${formattedFilters[filterKey]}`}
          className="flex w-full h-full items-center py-2 pl-3"
          to={{
            pathname: `/${encodeURIComponent(this.props.site.domain)}/filter/${filterGroupForFilter(filterKey)}`,
            search: window.location.search
          }}
        >
          <span className="inline-block max-w-2xs md:max-w-xs truncate">{text}</span>
        </Link>
        <span
          title={`Remove filter: ${formattedFilters[filterKey]}`}
          className="flex h-full w-full px-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 items-center"
          onClick={() => removeFilter(filterIndex, history, query)}
        >
          <XMarkIcon className="w-4 h-4" />
        </span>
      </span>
    )
  }

  renderDropdownButton() {
    if (this.state.wrapped === 2) {
      const filterCount = this.props.query.filters.length
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

  trackFilterMenu() {
    window.plausible && window.plausible('Filter Menu: Open', {u: `${window.location.protocol}//${window.location.hostname}/:dashboard`})
  }

  renderDropDown() {
    const { history, query, site } = this.props;

    return (
      <Menu as="div" className="md:relative ml-auto">
        {({ open }) => (
          <>
            <div>
              <Menu.Button onClick={this.trackFilterMenu} className="flex items-center text-xs md:text-sm font-medium leading-tight px-3 py-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded">
                {this.renderDropdownButton()}
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
                  <DropdownContent history={history} query={query} site={site} wrapped={this.state.wrapped} />
                </div>
              </Menu.Items>
            </Transition>
          </>
        )}
      </Menu>
    );
  }

  renderFilterList() {
    const { history, query } = this.props;

    if (this.state.wrapped !== 2) {
      return (
        <div id="filters" className="flex flex-wrap">
          {query.filters.map((filter, index) => this.renderListFilter(index, filter, history, query))}
        </div>
      );
    }

    return null
  }

  render() {
    return (
      <>
        {this.renderFilterList()}
        {this.renderDropDown()}
      </>
    )
  }
}

export default withRouter(Filters);
