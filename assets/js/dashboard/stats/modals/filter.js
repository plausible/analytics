import React from "react";
import { withRouter, Redirect } from 'react-router-dom'

import Datamap from 'datamaps'
import SearchSelect from '../../components/search-select'
import Modal from './modal'
import { parseQuery, formattedFilters, navigateToQuery } from '../../query'
import Transition from "../../../transition";
import * as api from '../../api'

function getFilterValue(selectedFilter, query) {
  const negated = !!query.filters[selectedFilter] && query.filters[selectedFilter][0] === '!'
  let filterValue = negated ? query.filters[selectedFilter].slice(1) : (query.filters[selectedFilter] || "")

  if (selectedFilter == 'country') {
    const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const selectedCountry = allCountries.find((c) => c.id === filterValue) || { properties: { name: filterValue } };
    filterValue = selectedCountry.properties.name
  }

  return {filterValue, negated}
}


class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const selectedFilter = this.props.match.params.field || 'page'

    this.state = Object.assign({selectedFilter, query}, getFilterValue(selectedFilter, query))

    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
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

  fetchOptions(input) {
    const {query, selectedFilter} = this.state
    const updatedQuery = { ...query, filters: { ...query.filters, [selectedFilter]: null } }

    if (selectedFilter === 'country') {
      const matchedCountries = Datamap.prototype.worldTopo.objects.world.geometries.filter(c => c.properties.name.includes(input.trim()))
      const matches = matchedCountries.map(c => c.id)

      return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/suggestions/country`, updatedQuery, { q: matches })
        .then((res) => {
          return res.map(code => matchedCountries.filter(c => c.id == code)[0].properties.name)
        })
    } else {
      return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/suggestions/${selectedFilter}`, updatedQuery, { q: input.trim() })
    }
  }

  onInput(val) {
    this.setState({filterValue: val})
  }

  renderSearchSelector(filter) {
    return (
      <SearchSelect
        key={this.state.selectedFilter}
        fetchOptions={this.fetchOptions.bind(this)}
        initialSelectedItem={this.state.filterValue}
        onInput={this.onInput.bind(this)}
      />
    )
  }

  selectFilterAndCloseModal(filterKey, filterValue) {
    const queryString = new URLSearchParams(window.location.search)

    if (filterValue) {
      queryString.set(filterKey, filterValue)
    } else {
      queryString.delete(filterKey)
    }

    this.props.history.replace({pathname: `/${encodeURIComponent(this.props.site.domain)}`, search: queryString.toString()})
  }

  handleSubmit() {
    const { selectedFilter, negated, filterValue } = this.state;

    let finalFilterValue = (this.negationSupported(selectedFilter) && negated ? '!' : '') + filterValue.trim()
    if (selectedFilter == 'country') {
      const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
      const selectedCountry = allCountries.find((c) => c.properties.name === finalFilterValue) || { id: finalFilterValue };
      finalFilterValue = selectedCountry.id
    }

    this.selectFilterAndCloseModal(selectedFilter, finalFilterValue)
  }

  updateSelectedFilter(e) {
    this.setState(Object.assign({selectedFilter: e.target.value}, getFilterValue(e.target.value, this.state.query)))
  }

  renderBody() {
    const { selectedFilter, negated, filterValue, query } = this.state;
    const editableFilters = Object.keys(this.state.query.filters).filter(filter => !['props'].includes(filter))

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">{query.filters[selectedFilter] ? 'Edit' : 'Add'} Filter</h1>

        <div className="my-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" id="filter-form" onSubmit={this.handleSubmit}>
            <select
              value={selectedFilter}
              className="my-2 block w-full pr-10 border-gray-300 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-200 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:bg-gray-900 dark:text-gray-300 cursor-pointer"
              placeholder="Select a Filter"
              onChange={this.updateSelectedFilter.bind(this)}
            >
              <option disabled value="" className="hidden">Select a Filter</option>
              {editableFilters.map(filter => <option key={filter} value={filter}>{formattedFilters[filter]}</option>)}
            </select>

            {this.negationSupported(selectedFilter) && (
              <div className="my-4 flex items-center">
                <label className="text-gray-700 dark:text-gray-300 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    className="bg-gray-100 dark:bg-gray-900 text-indigo-600 border-gray-300 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-200 mr-2 relative inline-flex flex-shrink-0 h-6 w-8 border-1 rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none"
                    checked={negated}
                    name="exclude"
                    onChange={(e) => this.setState({ negated: e.target.checked })}
                  />
                  Exclude pages matching this filter
                </label>
              </div>
            )}

            {this.renderSearchSelector()}

            <button
              type="submit"
              disabled={filterValue.trim().length === 0}
              className="button mt-4 w-2/3 mx-auto"
            >
              {query.filters[selectedFilter] ? 'Update' : 'Add'} Filter
            </button>

            {query.filters[selectedFilter] && (
              <button
                className="button mt-8 px-4 mx-auto flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                onClick={() => {
                  this.selectFilterAndCloseModal(selectedFilter, null)
                }}
              >
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                Remove Filter
              </button>
            )}
          </form>
        </main>
      </>
    )
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
