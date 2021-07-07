import React, { Fragment } from "react";
import { withRouter, Redirect } from 'react-router-dom'
import classNames from 'classnames'
import Datamap from 'datamaps'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/solid'

import SearchSelect from '../../components/search-select'
import Modal from './modal'
import { parseQuery, formattedFilters, navigateToQuery } from '../../query'
import * as api from '../../api'

function getCountryName(ISOCode) {
  const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
  const selectedCountry = allCountries.find((c) => c.id === ISOCode);
  return selectedCountry.properties.name
}

function getFilterValue(filter, query) {
  const negated = !!query.filters[filter] && query.filters[filter][0] === '!'
  let filterValue = negated ? query.filters[filter].slice(1) : (query.filters[filter] || "")

  if (filter == 'country') {
    const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const selectedCountry = allCountries.find((c) => c.id === filterValue) || { properties: { name: filterValue } };
    filterValue = selectedCountry.properties.name
  }

  return {filterValue, negated}
}

function getFormState(filterGroup, query) {
  return FILTER_GROUPS[filterGroup].reduce((result, filter) => {
    let filterValue = query.filters[filter] || ''
    const type = filterValue[0] === '!' ? 'is_not' : 'is'
    if (filter === 'country') filterValue = getCountryName(filterValue)
    return Object.assign(result, {[filter]: {value: filterValue, type: type}})
  }, {})
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return 'a ' + word
  } else if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return 'an ' + word
  } else {
    return 'a ' + word
  }
}

export const FILTER_GROUPS = {
  'page': ['page'],
  'source': ['source', 'referrer'],
  'country': ['country'],
  'screen': ['screen'],
  'browser': ['browser', 'browser_version'],
  'os': ['os', 'os_version'],
  'utm': ['utm_medium', 'utm_source', 'utm_campaign'],
  'entry_page': ['entry_page'],
  'exit_page': ['exit_page'],
  'goal': ['goal']
}

export function formatFilterGroup(filterGroup) {
  if (filterGroup === 'utm') {
    return 'UTM tags'
  } else {
    return formattedFilters[filterGroup]
  }
}

export function filterGroupForFilter(filter) {
  const filterToGroupMap = Object.entries(FILTER_GROUPS).reduce((filterToGroupMap, [group, filtersInGroup]) => {
    for (const filter of filtersInGroup) {
      filterToGroupMap[filter] = group
    }
    return filterToGroupMap
  }, {})


  return filterToGroupMap[filter] || filter
}

class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const selectedFilterGroup = this.props.match.params.field || 'page'
    const formState = getFormState(selectedFilterGroup, query)

    this.state = Object.assign({selectedFilterGroup, query, formState})
  }

  componentDidMount() {
    document.addEventListener("keydown", this.handleKeydown)
  }

  componentWillUnmount() {
    document.removeEventListener("keydown", this.handleKeydown);
  }

  handleKeydown(e) {
    if (e.ctrlKey || e.metaKey || e.shiftKey || e.altKey || e.isComposing || e.keyCode === 229) return

    if (e.target.tagName == 'BODY' && e.key == 'Enter') {
      this.handleSubmit()
    }
  }

  negationSupported(filter) {
    return ['page', 'entry_page', 'exit_page'].includes(filter)
  }

  fetchOptions(filter) {
    return (input) => {
      const {query, formState} = this.state
      const formFilters = Object.fromEntries(
        Object.entries(formState).map(([k, v]) => [k, v.value])
      )
      const updatedQuery = { ...query, filters: { ...query.filters, ...formFilters, [filter]: null } }

      if (filter === 'country') {
        const matchedCountries = Datamap.prototype.worldTopo.objects.world.geometries.filter(c => c.properties.name.toLowerCase().includes(input.trim().toLowerCase()))
        const matches = matchedCountries.map(c => c.id)

        return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/suggestions/country`, updatedQuery, { q: matches })
          .then((res) => {
            return res.map(code => matchedCountries.filter(c => c.id == code)[0].properties.name)
          })
      } else {
        return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/suggestions/${filter}`, updatedQuery, { q: input.trim() })
      }
    }
  }

  onInput(filterName) {
    return (val) => {
      this.setState({formState: Object.assign(this.state.formState, {
        [filterName]: Object.assign(this.state.formState[filterName], {value: val})
      })})
    }
  }

  setFilterType(filterName, newType) {
    this.setState({formState: Object.assign(this.state.formState, {
      [filterName]: Object.assign(this.state.formState[filterName], {type: newType})
    })})
  }

  selectedFilterType(filter) {
    return this.state.formState[filter].type
  }

  renderFilterTypeSelector(filterName) {
    return (
      <Menu as="div" className="relative inline-block text-left">
        {({ open }) => (
          <>
            <div className="w-24">
              <Menu.Button className="inline-flex justify-between items-center w-full rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-sm text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 focus:ring-indigo-500">
                { this.selectedFilterType(filterName) }
                <ChevronDownIcon className="-mr-2 ml-2 h-4 w-4 text-gray-500" aria-hidden="true" />
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
                className="z-10 origin-top-left absolute left-0 mt-2 w-24 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 focus:outline-none"
              >
                <div className="py-1">
                  <Menu.Item>
                    {({ active }) => (
                      <span
                        onClick={() => this.setFilterType(filterName, 'is')}
                        className={classNames(
                          active ? 'bg-gray-100 text-gray-900' : 'text-gray-700',
                          'cursor-pointer block px-4 py-2 text-sm'
                        )}
                      >
                        is
                      </span>
                    )}
                  </Menu.Item>
                  <Menu.Item>
                    {({ active }) => (
                      <span
                        onClick={() => this.setFilterType(filterName, 'is_not')}
                        className={classNames(
                          active ? 'bg-gray-100 text-gray-900' : 'text-gray-700',
                          'cursor-pointer block px-4 py-2 text-sm'
                        )}
                      >
                        is not
                      </span>
                    )}
                  </Menu.Item>
                </div>
              </Menu.Items>
            </Transition>
          </>
        )}
      </Menu>
    )
  }

  renderFilterInputs() {
    return FILTER_GROUPS[this.state.selectedFilterGroup].map((filter) => {
      return (
        <div className="mt-4" key={filter}>
          <div className="text-sm font-medium text-gray-700 dark:text-gray-300">{ formattedFilters[filter] }</div>
          <div className="flex items-start mt-1">
            { this.renderFilterTypeSelector(filter) }

            <SearchSelect
              key={filter}
              fetchOptions={this.fetchOptions(filter)}
              initialSelectedItem={this.state.formState[filter].value}
              onInput={this.onInput(filter)}
              placeholder={`Select ${withIndefiniteArticle(formattedFilters[filter])}`}
            />
          </div>

        </div>
      )
    })
  }

  selectFiltersAndCloseModal(filters) {
    const queryString = new URLSearchParams(window.location.search)

    for (const entry of filters) {
      if (entry.value) {
        queryString.set(entry.filter, entry.value)
      } else {
        queryString.delete(entry.filter)
      }
    }

    this.props.history.replace({pathname: `/${encodeURIComponent(this.props.site.domain)}`, search: queryString.toString()})
  }

  handleSubmit() {
    const { formState } = this.state;

    const filters = Object.entries(formState).reduce((res, [filterKey, {type, value}]) => {
      let finalFilterValue = (type === 'is_not' ? '!' : '') + value.trim()

      if (filterKey == 'country') {
        const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
        const selectedCountry = allCountries.find((c) => c.properties.name === finalFilterValue) || { id: finalFilterValue };
        finalFilterValue = selectedCountry.id
      }

      res.push({filter: filterKey, value: finalFilterValue})
      return res
    }, [])

    this.selectFiltersAndCloseModal(filters)
  }

  updateSelectedFilterGroup(e) {
    this.setState({selectedFilterGroup: e.target.value, formState: getFormState(e.target.value, this.state.query)});
  }

  renderFilterSelector() {
    const editableFilters = Object.keys(FILTER_GROUPS)
    if (!this.props.match.params.field) {
      return (
        <select
          value={this.state.selectedFilterGroup}
          className="my-2 block w-full pr-10 border-gray-300 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-200 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:bg-gray-900 dark:text-gray-300 cursor-pointer"
          placeholder="Select a Filter"
          onChange={this.updateSelectedFilterGroup.bind(this)}
        >
          <option disabled value="" className="hidden">Select a Filter</option>
          {editableFilters.map(filter => <option key={filter} value={filter}>{formatFilterGroup(filter)}</option>)}
        </select>
      )
    }
  }

  renderBody() {
    const { selectedFilterGroup, query } = this.state;
    const editableFilters = Object.keys(FILTER_GROUPS)

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Filter by {formatFilterGroup(selectedFilterGroup)}</h1>

        <div className="mt-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" id="filter-form" onSubmit={this.handleSubmit.bind(this)}>
            {this.renderFilterSelector()}
            {this.renderFilterInputs()}

            <div className="mt-6 flex items-center justify-start">
              <button
                type="submit"
                className="button"
              >
                Save Filter
              </button>

              {query.filters[selectedFilterGroup] && (
                <button
                  className="ml-2 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                  onClick={() => {
                    this.selectFiltersAndCloseModal([{filter: selectedFilterGroup, value: null}])
                  }}
                >
                  <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                  Remove
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
        <p className="mt-6 text-xs text-gray-500">Hint: You can use double asterisks to match any character e.g. /blog**</p>
      )
    }
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
