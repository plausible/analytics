import React from "react";
import { withRouter } from 'react-router-dom'

import FilterTypeSelector from "../../components/filter-type-selector";
import Combobox from '../../components/combobox'
import { FILTER_GROUPS, formatFilterGroup, formattedFilters, toFilterQuery, FILTER_OPERATIONS } from '../../util/filters'
import { parseQuery } from '../../query'
import * as api from '../../api'
import { apiPath, siteBasePath, PlausibleSearchParams } from '../../util/url'
import { shouldIgnoreKeypress } from '../../keybinding'
import { isFreeChoiceFilter } from "../../util/filters"

function populateDefaults(filterGroup, filters) {
  return FILTER_GROUPS[filterGroup].reduce((result, key) => {
    const existingFilters = filters.filter(([_, filterKey]) => filterKey == key)

    if (existingFilters.length == 0) {
      return Object.assign(result, { [key]: [FILTER_OPERATIONS.is, key, []] })
    } else {
      // :TODO: handling value/label dichotomy
      const entries = existingFilters.map((filter, index) =>
        [index == 0 ? key : `key${index}`, filter]
      )
      return Object.assign(result, Object.fromEntries(entries))
    }
  }, {})
}

function cleanLabels(filterState, labels, mergedFilterKey, mergedLabels) {
  let result = labels
  if (mergedFilterKey && ['country', 'region', 'city'].includes(mergedFilterKey)) {
    result = {
      ...result,
      [mergedFilterKey]: mergedLabels
    }
  }
  return result
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${word}`
  } if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return `an ${word}`
  }
  return `a ${word}`
}

class RegularFilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const filterState = populateDefaults(props.filterGroup, query.filters)

    this.handleKeydown = this.handleKeydown.bind(this)
    this.state = { query, filterState, labelState: query.labels }
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
    const filters = Object.values(this.state.filterState).filter(([ _op, _key, clauses ]) => clauses.length > 0)
    this.selectFiltersAndCloseModal(filters, this.state.labelState)
  }

  onComboboxSelect(key) {
    return (selection) => {
      this.setState(prevState => {
        const [operation, filterKey, _clauses] = prevState.filterState[key]
        const newClauses = selection.map(({ value }) => value)

        const filterState = Object.assign(prevState.filterState, { [key]: [operation, filterKey, newClauses] })
        const newLabels = Object.fromEntries(selection.map(({ label, value }) => [value, label]))
        return {
          filterState,
          labelState: cleanLabels(filterState, prevState.labels, filterKey, newLabels)
        }
      })
    }
  }

  onOperationSelect(key) {
    return (newOperation) => {
      this.setState(prevState => {
        const [_operation, filterKey, clauses] = prevState.filterState[key]
        return {
          filterState: Object.assign(prevState.filterState, { [key]: [newOperation, filterKey, clauses] })
        }
      })
    }
  }

  fetchOptions(key) {
    return (input) => {
      const { query, filterState } = this.state
      const [operation, filterKey, _clauses] = this.state.filterState[key]
      if (operation === FILTER_OPERATIONS.contains) {return Promise.resolve([])}

      const formFilters = Object.fromEntries(
        Object.values(filterState)
          .filter(([_operation, _filterKey, clauses]) => clauses.length > 0)
          .map(([operation, filterKey, clauses]) => [filterKey, toFilterQuery(operation, clauses)])
      )
      const updatedQuery = this.queryForSuggestions(query, formFilters, filterKey)
      return api.get(apiPath(this.props.site, `/suggestions/${filterKey}`), updatedQuery, { q: input.trim() })
    }
  }

  queryForSuggestions(query, formFilters, filter) {
    // :TODO: Handle formFilters properly
    return { ...query, filters: { ...query.filters, ...formFilters, [filter]: this.negate(formFilters[filter]) } }
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

  isDisabled() {
    return Object.values(this.state.filterState).every(([_operation, _key, clauses]) => clauses.length === 0)
  }

  selectFiltersAndCloseModal(filters, labels) {
    const queryString = new PlausibleSearchParams(window.location.search)

    if (filters.length > 0) {
      queryString.set('filters', filters)
    } else {
      queryString.delete('filters')
    }

    if (labels) {
      queryString.set('labels', labels)
    } else {
      queryString.delete('labels')
    }

    // :TODO: Use navigateToQuery or something similar
    this.props.history.replace({ pathname: siteBasePath(this.props.site), search: queryString.toString() })
  }

  selectedClauses(key) {
    const [_operation, filterKey, clauses] = this.state.filterState[key]
    return clauses.map((value) => ({ value, label: this.labelFor(filterKey, value) }))
  }

  labelFor(filterKey, value) {
    if (['country', 'region', 'city'].includes(filterKey)) {
      return this.state.labelState[filterKey][value]
    } else {
      return value
    }
  }

  renderFilterInputs() {
    const filtersInGroup = FILTER_GROUPS[this.props.filterGroup]

    return filtersInGroup.map((key) => {
      const [operation, filterKey, _clauses] = this.state.filterState[key]
      return (
        <div className="mt-4" key={key}>
          <div className="text-sm font-medium text-gray-700 dark:text-gray-300">{formattedFilters[filterKey]}</div>
          <div className="grid grid-cols-11 mt-1">
            <div className="col-span-3 mr-2">
              <FilterTypeSelector forFilter={filterKey} onSelect={this.onOperationSelect(key)} selectedType={operation}/>
            </div>
            <div className="col-span-8">
              <Combobox
                fetchOptions={this.fetchOptions(key)}
                freeChoice={isFreeChoiceFilter(filterKey)}
                values={this.selectedClauses(key)}
                onSelect={this.onComboboxSelect(key)}
                placeholder={`Select ${withIndefiniteArticle(formattedFilters[filterKey])}`}
              />
            </div>
          </div>
        </div>
      )
    })
  }

  render() {
    const { filterGroup } = this.props
    const { query } = this.state
    const showClear = FILTER_GROUPS[filterGroup].some((filterName) => query.filters[filterName])

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Filter by {formatFilterGroup(filterGroup)}</h1>

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
                    // :TODO:
                    // const updatedFilters = FILTER_GROUPS[filterGroup].map((filterName) => ({ filter: filterName, value: null }))

                    // this.selectFiltersAndCloseModal(updatedFilters)
                  }}
                >
                  <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                  Remove filter{FILTER_GROUPS[filterGroup].length > 1 ? 's' : ''}
                </button>
              )}
            </div>
          </form>
        </main>
      </>
    )
  }
}

export default withRouter(RegularFilterModal)
