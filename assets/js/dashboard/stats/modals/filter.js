import React from "react";
import { withRouter, Redirect } from 'react-router-dom'

import Modal from './modal'
import { parseQuery, formattedFilters, navigateToQuery } from '../../query'
import Transition from "../../../transition";
import * as api from '../../api'
import Datamap from 'datamaps'

class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      query: parseQuery(props.location.search, props.site),
      selectedFilter: "",
      negated: false,
      updatedValue: "",
      filterSaved: false,
      suggestions: [],
      fetchSuggestionsTimeout: undefined,
      focusedSuggestionIndex: -1,
      preventSuggestions: true
    }

    this.editableGoals = Object.keys(this.state.query.filters).filter(filter => !['props'].includes(filter))
    this.renderSelector = this.renderSelector.bind(this)
    this.fetchSuggestions = this.fetchSuggestions.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  componentDidMount() {
    this.setState({ selectedFilter: this.props.match.params.field })

    document.addEventListener("keydown", this.handleKeydown);
  }

  componentDidUpdate(prevProps, prevState) {
    const { query, selectedFilter, updatedValue, preventSuggestions, fetchSuggestionsTimeout } = this.state

    if (prevState.selectedFilter !== selectedFilter) {
      const negated = query.filters[selectedFilter] && query.filters[selectedFilter][0] == '!' && this.negationSupported(selectedFilter)
      let updatedValue = negated ? query.filters[selectedFilter].slice(1) : (query.filters[selectedFilter] || "")
      clearTimeout(fetchSuggestionsTimeout)

      if (selectedFilter == 'country') {
        const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
        const selectedCountry = allCountries.find((c) => c.id === updatedValue) || { properties: { name: updatedValue } };
        updatedValue = selectedCountry.properties.name
      }

      this.setState({ updatedValue, negated, suggestions: [], fetchSuggestionsTimeout: undefined, focusedSuggestionIndex: -1, noSuggestions: false }, () => {
        if (selectedFilter) {
          this.fetchSuggestions()
        }
      })
    }

    if (prevState.updatedValue !== updatedValue) {
      if (!preventSuggestions || prevState.preventSuggestions) {
        let fetchSuggestionsTimeout;
        clearTimeout(this.state.fetchSuggestionsTimeout)

        this.setState({ suggestions: [], preventSuggestions: false, focusedSuggestionIndex: -1, noSuggestions: false }, () => {
          this.setState({ fetchSuggestionsTimeout: setTimeout(this.fetchSuggestions, 200) })
        })
      } else {
        this.setState({ suggestions: [], fetchSuggestionsTimeout: undefined, focusedSuggestionIndex: -1, noSuggestions: false })
      }
    }
  }

  componentWillUnmount() {
    document.removeEventListener("keydown", this.handleKeydown);
  }

  handleKeydown(e) {
    const { suggestions } = this.state
    let { focusedSuggestionIndex, updatedValue, preventSuggestions, selectedFilter } = this.state
    const navigationKeys = ['ArrowUp', undefined, 'ArrowDown']

    if (e.target.id !== 'suggestions_input') return true
    if (e.ctrlKey || e.metaKey || e.shiftKey || e.altKey || e.isComposing || e.keyCode === 229) return

    if ((e.key === 'Enter' || e.key === 'Tab') && suggestions[focusedSuggestionIndex]) {
      updatedValue = suggestions[focusedSuggestionIndex]
      focusedSuggestionIndex = -1
      preventSuggestions = true
      e.preventDefault()
    }

    if (navigationKeys.includes(e.key)) {
      focusedSuggestionIndex += navigationKeys.indexOf(e.key) - 1
      if (focusedSuggestionIndex < 0) {
        focusedSuggestionIndex = suggestions.length - 1
      } else if (focusedSuggestionIndex >= suggestions.length) {
        focusedSuggestionIndex = 0
      }
      e.preventDefault()
    }

    this.setState({ focusedSuggestionIndex, updatedValue, preventSuggestions })
  }

  negationSupported(filter) {
    return ['page', 'entry_page', 'exit_page'].includes(filter)
  }

  fetchSuggestions() {
    const { query, updatedValue, selectedFilter } = this.state
    const updatedQuery = { ...query, filters: { ...query.filters, [selectedFilter]: null } }

    if (selectedFilter == 'country') {
      const matchedCountries = Datamap.prototype.worldTopo.objects.world.geometries.filter(c => c.properties.name.includes(updatedValue.trim()))
      const matches = matchedCountries.map(c => c.id)

      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/suggestions/country`, updatedQuery, { q: matches })
        .then((res) => {
          const suggestions = res.map(code => matchedCountries.filter(c => c.id == code)[0].properties.name)

          this.setState({ suggestions, fetchSuggestionsTimeout: undefined, focusedSuggestionIndex: -1, noSuggestions: res.length == 0 })
        })
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/suggestions/${selectedFilter}`, updatedQuery, { q: updatedValue.trim() })
        .then((res) => {
          this.setState({ suggestions: res, fetchSuggestionsTimeout: undefined, focusedSuggestionIndex: -1, noSuggestions: res.length == 0 })
        })
    }
  }

  renderSelector(filter) {
    const { updatedValue, suggestions, inputFocused, focusedSuggestionIndex, selectedFilter } = this.state;

    if (!filter) return null

    return <div className="relative">
      <input
        id="suggestions_input"
        type="text"
        className="mt-4 bg-gray-100 dark:bg-gray-900 outline-none appearance-none border border-transparent rounded w-full p-2 text-gray-700 dark:text-gray-300 leading-normal focus:outline-none focus:bg-white dark:focus:bg-gray-800 focus:border-gray-300 dark:focus:border-gray-500"
        value={updatedValue}
        placeholder="Filter value"
        onChange={(e) => {
          this.setState({
            updatedValue: e.target.value
          })
        }}
        onFocus={() => {
          this.setState({ inputFocused: true })
        }}
        onBlur={() => this.setState({ inputFocused: false })}
      />
      <Transition
        show={!!suggestions.length && inputFocused}
        enter="transition ease-out duration-100 transform"
        enterFrom="opacity-0 scale-95"
        enterTo="opacity-100 scale-100"
        leave="transition ease-in duration-75 transform"
        leaveFrom="opacity-100 scale-100"
        leaveTo="opacity-0 scale-95"
      >
        <div
          className="absolute mt-2 rounded shadow-md z-10"
          style={{ width: '360px' }}
        >
          <div className="rounded bg-white dark:bg-gray-850 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200 py-1">
            {suggestions.map((suggestion, index) => (
              <span
                key={suggestion}
                className={`${focusedSuggestionIndex == index ? 'ring-2 ring-inset ring-opacity-50' : ''} rounded px-4 py-2 md:text-sm leading-tight hover:bg-gray-200 dark:hover:bg-gray-950 hover:text-gray-900 dark:hover:text-gray-100 flex items-center justify-between cursor-pointer`}
                onClick={() => {
                  this.setState({ updatedValue: suggestion, preventSuggestions: true, suggestions: [] })
                }}
              >
                {suggestion}
              </span>))}
          </div>
        </div>
      </Transition>
    </div>
  }

  renderBody() {
    const { selectedFilter, negated, updatedValue, query, noSuggestions } = this.state;

    const validFilter = this.editableGoals.includes(selectedFilter) && updatedValue.trim()

    return (
      <React.Fragment>
        <h1 className="text-xl font-bold dark:text-gray-100">{query.filters[selectedFilter] ? 'Edit' : 'Add'} Filter</h1>

        <div className="my-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" onSubmit={() => {
            let finalFilterValue = (this.negationSupported(selectedFilter) && negated ? '!' : '') + updatedValue.trim()
            if (selectedFilter == 'country') {
              const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
              const selectedCountry = allCountries.find((c) => c.properties.name === finalFilterValue) || { id: finalFilterValue };
              finalFilterValue = selectedCountry.id
            }
            const finalizedQuery = new URLSearchParams(window.location.search)
            finalizedQuery.set(selectedFilter, finalFilterValue)

            if (validFilter) {
              this.setState({ finalizedQuery })
            }
          }}>
            <select
              value={selectedFilter}
              className="my-2 block w-full py-2 pl-3 pr-10 text-base border-gray-300 dark:border-gray-700 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:bg-gray-900 dark:text-gray-300"
              placeholder="Select a Filter"
              onChange={(e) => this.setState({ selectedFilter: e.target.value })}
            >
              <option disabled value="" className="hidden">Select a Filter</option>
              {this.editableGoals.map(filter => <option key={filter} value={filter}>{formattedFilters[filter]}</option>)}
            </select>

            {this.negationSupported(selectedFilter) &&
              <div className="mt-4 flex items-center">
                <label className="text-gray-700 dark:text-gray-300 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    className={"text-indigo-600 bg-gray-100 dark:bg-gray-700 mr-2 relative inline-flex flex-shrink-0 h-6 w-8 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none"}
                    checked={negated}
                    name="exclude"
                    onChange={(e) => this.setState({ negated: e.target.checked })}
                  />
                  Exclude pages matching this filter
                </label>
              </div>
            }

            {this.renderSelector(selectedFilter)}

            {noSuggestions &&
              <span className="text-red-500 text-md flex mt-2 px-3">
                <svg className="w-8 h-8 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span className="">No results found in current dashboard, try removing some filters{updatedValue.trim().length ? ', checking your input' : ''} and ensuring this data exists</span>
              </span>
            }

            <button
              type="submit"
              disabled={!validFilter}
              className={"button mt-4 w-2/3 mx-auto"}
            >
              {query.filters[selectedFilter] ? 'Update' : 'Add'} Filter
            </button>

            {query.filters[selectedFilter] &&
              <button
                className={"button mt-8 px-4 mx-auto flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"}
                onClick={() => {
                  const finalizedQuery = new URLSearchParams(window.location.search)
                  finalizedQuery.delete(selectedFilter)
                  this.setState({ finalizedQuery })
                }}
              >
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                Remove Filter
              </button>
            }

          </form>
        </main>
      </React.Fragment>
    )
  }

  render() {
    const { finalizedQuery } = this.state

    if (finalizedQuery) {
      return <Redirect to={{ pathname: `/${encodeURIComponent(this.props.site.domain)}`, search: finalizedQuery.toString() }} />
    }

    return (
      <Modal site={this.props.site} maxWidth="460px">
        { this.renderBody()}
      </Modal>
    )
  }
}

export default withRouter(FilterModal)
