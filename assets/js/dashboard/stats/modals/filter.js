import React, { Fragment } from "react";
import { withRouter } from 'react-router-dom'
import classNames from 'classnames'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'

import Combobox from '../../components/combobox'
import Modal from './modal'
import { FILTER_GROUPS, parseQueryFilter, formatFilterGroup, formattedFilters, toFilterQuery, FILTER_TYPES } from '../../util/filters'
import { parseQuery } from '../../query'
import * as api from '../../api'
import { apiPath, siteBasePath } from '../../util/url'
import { shouldIgnoreKeypress } from '../../keybinding'

function getFormState(filterGroup, query) {
  if (filterGroup === 'props') {
    const propsObject = query.filters['props']
    const entries = propsObject && Object.entries(propsObject)

    if (entries && entries.length == 1) {
      const [[propKey, _propVal]] = entries
      const {type, clauses} = parseQueryFilter(query, 'props')

      return {
        'prop_key': { type: FILTER_TYPES.is, clauses: [{label: propKey, value: propKey}] },
        'prop_value': { type, clauses }
      }
    }
  }

  return FILTER_GROUPS[filterGroup].reduce((result, filter) => {
    const {type, clauses} = parseQueryFilter(query, filter)

    return Object.assign(result, { [filter]: { type, clauses } })
  }, {})
}

function supportsIsNot(filterName) {
  return !['goal', 'prop_key'].includes(filterName)
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${word}`
  } if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return `an ${word}`
  }
  return `a ${word}`

}

class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const selectedFilterGroup = this.props.match.params.field || 'page'
    const formState = getFormState(selectedFilterGroup, query)

    this.state = { selectedFilterGroup, query, formState }
  }

  componentDidMount() {
    document.addEventListener("keydown", this.handleKeydown)
  }

  componentWillUnmount() {
    document.removeEventListener("keydown", this.handleKeydown);
  }

  handleKeydown(e) {
    if (shouldIgnoreKeypress(e)) return

    if (e.target.tagName === 'BODY' && e.key === 'Enter') {
      this.handleSubmit()
    }
  }

  handleSubmit() {
    const { formState } = this.state;

    const filters = Object.entries(formState).reduce((res, [filterKey, { type, clauses }]) => {
      if (clauses.length === 0) { return res }
      if (filterKey === 'country') { res.push({ filter: 'country_labels', value: clauses.map(clause => clause.label).join('|') }) }
      if (filterKey === 'region') { res.push({ filter: 'region_labels', value: clauses.map(clause => clause.label).join('|') }) }
      if (filterKey === 'city') { res.push({ filter: 'city_labels', value: clauses.map(clause => clause.label).join('|') }) }
      if (filterKey === 'prop_value') { return res }
      if (filterKey === 'prop_key') {
        const [{value: propKey}] = clauses
        res.push({ filter: 'props', value: JSON.stringify({ [propKey]: toFilterQuery(formState.prop_value.type, formState.prop_value.clauses) }) })
        return res
      }

      res.push({ filter: filterKey, value: toFilterQuery(type, clauses) })
      return res
    }, [])

    this.selectFiltersAndCloseModal(filters)
  }

  onChange(filterName) {
    return (selection) => {
      this.setState(prevState => ({
        formState: Object.assign(prevState.formState, {
          [filterName]: Object.assign(prevState.formState[filterName], { clauses: selection })
        })
      }))
    }
  }

  setFilterType(filterName, newType) {
    this.setState(prevState => ({
      formState: Object.assign(prevState.formState, {
        [filterName]: Object.assign(prevState.formState[filterName], { type: newType })
      })
    }))
  }

  fetchOptions(filter) {
    return (input) => {
      const { query, formState } = this.state
      if (formState[filter].type === FILTER_TYPES.contains) {return Promise.resolve([])}

      const formFilters = Object.fromEntries(
        Object.entries(formState)
          .filter(([_filter, {_type, clauses}]) => clauses.length > 0)
          .map(([filter, {type, clauses}]) => [filter, toFilterQuery(type, clauses)])
      )
      const updatedQuery = this.queryForSuggestions(query, formFilters, filter)
      return api.get(apiPath(this.props.site, `/suggestions/${filter}`), updatedQuery, { q: input.trim() })
    }
  }

  queryForSuggestions(query, formFilters, filter) {
    if (filter === 'prop_key') {
      const propsFilter = formFilters.prop_value ? { '': formFilters.prop_value } : null
      return { ...query, filters: { ...query.filters, props: propsFilter } }
    } else if (filter === 'prop_value') {
      const propsFilter = formFilters.prop_key ? { [formFilters.prop_key]: '!(none)' } : null
      return { ...query, filters: { ...query.filters, props: propsFilter } }
    } else {
      return { ...query, filters: { ...query.filters, ...formFilters, [filter]: this.negate(formFilters[filter]) } }
    }
  }

  negate(filterVal) {
    if (!filterVal) {
      return filterVal
    } else if (filterVal.startsWith('!')) {
      return filterVal
    } else if (filterVal.startsWith('~')) {
      return null
    } else {
      return '!' + filterVal
    }
  }

  selectedFilterType(filter) {
    return this.state.formState[filter].type
  }

  isDisabled() {
    if (this.state.selectedFilterGroup === 'props') {
      return Object.entries(this.state.formState).some(([_key, { clauses }]) => clauses.length === 0)
    } else {
      return Object.entries(this.state.formState).every(([_key, { clauses }]) => clauses.length === 0)
    }
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

    this.props.history.replace({ pathname: siteBasePath(this.props.site), search: queryString.toString() })
  }

  isFreeChoice() {
    return ['page', 'utm'].includes(this.state.selectedFilterGroup)
  }

  renderSearchBox(filter) {
    return <Combobox fetchOptions={this.fetchOptions(filter)} freeChoice={this.isFreeChoice()} values={this.state.formState[filter].clauses} onChange={this.onChange(filter)} placeholder={`Select ${withIndefiniteArticle(formattedFilters[filter])}`} />
  }

  renderFilterInputs() {
    const groups = FILTER_GROUPS[this.state.selectedFilterGroup]

    return groups.map((filter) => {
      return (
        <div className="mt-4" key={filter}>
          <div className="text-sm font-medium text-gray-700 dark:text-gray-300">{formattedFilters[filter]}</div>
          <div className="flex items-start mt-1">
            {this.renderFilterTypeSelector(filter)}
            {this.renderSearchBox(filter)}
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
                {this.selectedFilterType(filterName)}
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
                  {this.renderTypeItem(filterName, FILTER_TYPES.is, true)}
                  {this.renderTypeItem(filterName, FILTER_TYPES.isNot, supportsIsNot(filterName))}
                  {this.renderTypeItem(filterName, FILTER_TYPES.contains, this.isFreeChoice())}
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
              {type}
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
          <form className="flex flex-col" onSubmit={this.handleSubmit.bind(this)}>
            {this.renderFilterInputs()}

            <div className="mt-6 flex items-center justify-start">
              <button
                type="submit"
                className="button"
                disabled={this.isDisabled()}
              >
                Apply Filter
              </button>

              {showClear && (
                <button
                  type="button"
                  className="ml-2 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                  onClick={() => {
                    const updatedFilters = FILTER_GROUPS[selectedFilterGroup].map((filterName) => ({ filter: filterName, value: null }))
                    this.selectFiltersAndCloseModal(updatedFilters)
                  }}
                >
                  <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                  Remove filter{FILTER_GROUPS[selectedFilterGroup].length > 1 ? 's' : ''}
                </button>
              )}
            </div>
          </form>
        </main>
      </>
    )
  }

  render() {
    return (
      <Modal site={this.props.site} maxWidth="460px">
        {this.renderBody()}
      </Modal>
    )
  }
}

export default withRouter(FilterModal)
