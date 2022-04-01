import React, { Fragment } from "react";
import { withRouter } from 'react-router-dom'
import classNames from 'classnames'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/solid'

import SearchSelect from '../../components/search-select'
import Modal from './modal'
import { parseQuery, formattedFilters } from '../../query'
import * as api from '../../api'
import {apiPath, siteBasePath} from '../../util/url'

export const FILTER_GROUPS = {
  'page': ['page', 'entry_page', 'exit_page'],
  'source': ['source', 'referrer'],
  'location': ['country', 'region', 'city'],
  'screen': ['screen'],
  'browser': ['browser', 'browser_version'],
  'os': ['os', 'os_version'],
  'utm': ['utm_medium', 'utm_source', 'utm_campaign', 'utm_term', 'utm_content'],
  'goal': ['goal']
}

function getFormState(filterGroup, query) {
  return FILTER_GROUPS[filterGroup].reduce((result, filter) => {
    const rawFilterValue = query.filters[filter] || ''
    const type = toFilterType(rawFilterValue)
    const filterValue = valueWithoutPrefix(rawFilterValue)

    let filterName = filterValue

    if (filter === 'country' && filterValue !== '') {
      filterName = (new URLSearchParams(window.location.search)).get('country_name')
    }
    if (filter === 'region' && filterValue !== '') {
      filterName = (new URLSearchParams(window.location.search)).get('region_name')
    }
    if (filter === 'city' && filterValue !== '') {
      filterName = (new URLSearchParams(window.location.search)).get('city_name')
    }
    return Object.assign(result, {[filter]: {name: filterName, value: filterValue, type}})
  }, {})
}

const FILTER_TYPES = {
  isNot: 'is not',
  contains: 'contains',
  is: 'is'
};

const FILTER_PREFIXES = {
  [FILTER_TYPES.isNot]: '!',
  [FILTER_TYPES.contains]: '~',
  [FILTER_TYPES.is]: ''
};

export function toFilterType(value) {
  return Object.keys(FILTER_PREFIXES)
    .find(type => FILTER_PREFIXES[type] === value[0]) || FILTER_TYPES.is;
}

export function valueWithoutPrefix(value) {
  return [FILTER_TYPES.isNot, FILTER_TYPES.contains].includes(toFilterType(value))
    ? value.substring(1)
    : value;
}

function toFilterQuery(value, type) {
  const prefix = FILTER_PREFIXES[type];
  return prefix + value.trim();
}

function supportsContains(filterName) {
  return ['page', 'entry_page', 'exit_page'].includes(filterName)
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${  word}`
  } if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return `an ${  word}`
  }
    return `a ${  word}`

}

export function formatFilterGroup(filterGroup) {
  if (filterGroup === 'utm') {
    return 'UTM tags'
  } else if (filterGroup === 'location') {
    return 'Location'
  } else {
    return formattedFilters[filterGroup]
  }
}

export function filterGroupForFilter(filter) {
  const map = Object.entries(FILTER_GROUPS).reduce((filterToGroupMap, [group, filtersInGroup]) => {
    const filtersToAdd = {}
    filtersInGroup.forEach((filterInGroup) => {
      filtersToAdd[filterInGroup] = group
    })

    return { ...filterToGroupMap, ...filtersToAdd}
  }, {})


  return map[filter] || filter
}

class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const selectedFilterGroup = this.props.match.params.field || 'page'
    const formState = getFormState(selectedFilterGroup, query)

    this.state = {selectedFilterGroup, query, formState}
  }

  componentDidMount() {
    document.addEventListener("keydown", this.handleKeydown)
  }

  componentWillUnmount() {
    document.removeEventListener("keydown", this.handleKeydown);
  }

  handleKeydown(e) {
    if (e.ctrlKey || e.metaKey || e.shiftKey || e.altKey || e.isComposing || e.keyCode === 229) {
      return
    }

    if (e.target.tagName === 'BODY' && e.key === 'Enter') {
      this.handleSubmit()
    }
  }

  handleSubmit() {
    const { formState } = this.state;

    const filters = Object.entries(formState).reduce((res, [filterKey, {type, value, name}]) => {
      if (filterKey === 'country') { res.push({filter: 'country_name', value: name}) }
      if (filterKey === 'region') { res.push({filter: 'region_name', value: name}) }
      if (filterKey === 'city') { res.push({filter: 'city_name', value: name}) }

      res.push({filter: filterKey, value: toFilterQuery(value, type)})
      return res
    }, [])

    this.selectFiltersAndCloseModal(filters)
  }

  onSelect(filterName) {
    if (this.state.selectedFilterGroup !== 'location') {
      return () => {}
    }

    return (value) => {
      this.setState(prevState => ({formState: Object.assign(prevState.formState, {
        [filterName]: Object.assign(prevState.formState[filterName], {value: value.code, name: value.name})
      })}))
    }
  }

  onInput(filterName) {
    if (this.state.selectedFilterGroup === 'location') {
      return () => {}
    }

    return (value) => {
      this.setState(prevState => ({formState: Object.assign(prevState.formState, {
        [filterName]: Object.assign(prevState.formState[filterName], {value})
      })}))
    }
  }

  setFilterType(filterName, newType) {
    this.setState(prevState => ({formState: Object.assign(prevState.formState, {
      [filterName]: Object.assign(prevState.formState[filterName], {type: newType})
    })}))
  }

  fetchOptions(filter) {
    return (input) => {
      const {query, formState} = this.state
      const formFilters = Object.fromEntries(
        Object.entries(formState).map(([k, v]) => [k, v.code || v.value])
      )
      const updatedQuery = {...query, filters: { ...query.filters, ...formFilters, [filter]: null }}

      return api.get(apiPath(this.props.site, `/suggestions/${filter}`), updatedQuery, { q: input.trim() })

    }
  }

  selectedFilterType(filter) {
    return this.state.formState[filter].type
  }

  isDisabled() {
    return Object.entries(this.state.formState).every(([_key, {value: val}]) => !val)
  }

  selectFiltersAndCloseModal(filters) {
    const queryString = new URLSearchParams(window.location.search)

    filters.forEach((entry) => {
      if (entry.value) {
        queryString.set(entry.filter, entry.value)
      } else {
        queryString.delete(entry.filter)
      }
    })

    this.props.history.replace({pathname: siteBasePath(this.props.site), search: queryString.toString()})
  }

  renderFilterInputs() {
    const groups = FILTER_GROUPS[this.state.selectedFilterGroup]

    return groups.map((filter) => {
      return (
        <div className="mt-4" key={filter}>
          <div className="text-sm font-medium text-gray-700 dark:text-gray-300">{ formattedFilters[filter] }</div>
          <div className="flex items-start mt-1">
            { this.renderFilterTypeSelector(filter) }

            <SearchSelect
              key={filter}
              fetchOptions={this.fetchOptions(filter)}
              initialSelectedItem={this.state.formState[filter]}
              onInput={this.onInput(filter)}
              onSelect={this.onSelect(filter)}
              placeholder={`Select ${withIndefiniteArticle(formattedFilters[filter])}`}
            />
          </div>
        </div>
      )
    })
  }

  renderFilterTypeSelector(filterName) {
    return (
      <Menu as="div" className="relative inline-block text-left">
        {({ open }) => (
          <>
            <div className="w-24">
              <Menu.Button className="inline-flex justify-between items-center w-full rounded-md border border-gray-300 dark:border-gray-500 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-850 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 dark:focus:ring-offset-gray-900 focus:ring-indigo-500">
                { this.selectedFilterType(filterName) }
                <ChevronDownIcon className="-mr-2 ml-2 h-4 w-4 text-gray-500 dark:text-gray-400" aria-hidden="true" />
              </Menu.Button>
            </div>

            <Transition
              show={open}
              as={Fragment}
              enter="transition ease-out duration-100"
              enterFrom="transform opacity-0 scale-95"
              enterTo="transform opacity-100 scale-100"
              leave="transition ease-in duration-75"
              leaveFrom="transform opacity-100 scale-100"
              leaveTo="transform opacity-0 scale-95"
            >
              <Menu.Items
                static
                className="z-10 origin-top-left absolute left-0 mt-2 w-24 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none"
              >
                <div className="py-1">
                  { this.renderTypeItem(filterName, FILTER_TYPES.is, true) }
                  { this.renderTypeItem(filterName, FILTER_TYPES.isNot, filterName !== 'goal') }
                  { this.renderTypeItem(filterName, FILTER_TYPES.contains, supportsContains(filterName)) }
                </div>
              </Menu.Items>
            </Transition>
          </>
        )}
      </Menu>
    )
  }

  renderTypeItem(filterName, type, shouldDisplay) {
    return (
      shouldDisplay && (
        <Menu.Item>
          {({ active }) => (
            <span
              onClick={() => this.setFilterType(filterName, type)}
              className={classNames(
                active ? "bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100" : "text-gray-700 dark:text-gray-200",
                "cursor-pointer block px-4 py-2 text-sm"
              )}
            >
              { type }
            </span>
          )}
        </Menu.Item>
      )
    );
  }

    renderBody() {
      const { selectedFilterGroup, query } = this.state;
      const showClear = FILTER_GROUPS[selectedFilterGroup].some((filterName) => query.filters[filterName])

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Filter by {formatFilterGroup(selectedFilterGroup)}</h1>

        <div className="mt-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" id="filter-form" onSubmit={this.handleSubmit.bind(this)}>
            {this.renderFilterInputs()}

            <div className="mt-6 flex items-center justify-start">
              <button
                type="submit"
                className="button"
                disabled={this.isDisabled()}
              >
                Save Filter
              </button>

              {showClear && (
                <button
                  type="button"
                  className="ml-2 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                  onClick={() => {
                    const updatedFilters = FILTER_GROUPS[selectedFilterGroup].map((filterName) => ({filter: filterName, value: null}))
                    this.selectFiltersAndCloseModal(updatedFilters)
                  }}
                >
                  <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                  Remove filter{FILTER_GROUPS[selectedFilterGroup].length > 1 ? 's' : ''}
                </button>
              )}
            </div>
          </form>
          {this.renderHints()}
        </main>
      </>
    )
  }

  renderHints() {
    if (['page', 'entry_page', 'exit_page'].includes(this.state.selectedFilterGroup)) {
      return (
        <p className="mt-6 text-xs text-gray-500">Hint: You can use double asterisks to match any character e.g. /blog** to group all of your blog posts. Or use double asterisks in front and back (e.g. **keyword**) to group all URLs containing a specific keyword.</p>
      )
    }

    return null
  }

  render() {
    return (
      <Modal site={this.props.site} maxWidth="460px">
        { this.renderBody()}
      </Modal>
    )
  }
}

export default withRouter(FilterModal)
