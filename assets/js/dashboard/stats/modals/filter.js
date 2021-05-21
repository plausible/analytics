import React from "react";
import { withRouter, Redirect } from 'react-router-dom'

import Modal from './modal'
import { parseQuery, formattedFilters, navigateToQuery } from '../../query'

class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      query: parseQuery(props.location.search, props.site),
      selectedFilter: "",
      negated: false,
      updatedValue: "",
      filterSaved: false
    }

    this.editableGoals = Object.keys(this.state.query.filters).filter(filter => !['goal', 'props'].includes(filter))
  }

  componentDidMount() {
    this.setState({ selectedFilter: this.props.match.params.field })
  }

  componentDidUpdate(prevProps, prevState) {
    const { query, selectedFilter } = this.state

    if (prevState.selectedFilter !== selectedFilter) {
      const negated = query.filters[selectedFilter] && query.filters[selectedFilter][0] == '!' && this.negationSupported(selectedFilter)
      const updatedValue = negated ? query.filters[selectedFilter].slice(1) : (query.filters[selectedFilter] || "")

      this.setState({ updatedValue, negated })
    }
  }

  negationSupported(filter) {
    return ['page', 'entry_page', 'exit_page'].includes(filter)
  }

  renderBody() {
    const { selectedFilter, negated, updatedValue, query } = this.state;

    const finalFilterValue = (this.negationSupported(selectedFilter) && negated ? '!' : '') + updatedValue
    const finalizedQuery = new URLSearchParams(window.location.search)
    const validFilter = this.editableGoals.includes(selectedFilter) && updatedValue
    finalizedQuery.set(selectedFilter, finalFilterValue)

    return (
      <React.Fragment>
        <h1 className="text-xl font-bold dark:text-gray-100">{query.filters[selectedFilter] ? 'Edit' : 'Add'} Filter</h1>

        <div className="my-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" onSubmit={() => {
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

            {selectedFilter &&
              <input
                type="text"
                className="mt-4 bg-gray-100 dark:bg-gray-900 outline-none appearance-none border border-transparent rounded w-full p-2 text-gray-700 dark:text-gray-300 leading-normal focus:outline-none focus:bg-white dark:focus:bg-gray-800 focus:border-gray-300 dark:focus:border-gray-500"
                value={updatedValue}
                placeholder="Filter value"
                onChange={(e) => { this.setState({ updatedValue: e.target.value }) }}
              />
            }

            <button
              type="submit"
              disabled={!validFilter}
              className={"button mt-4 w-2/3 mx-auto"}
            >
              {query.filters[selectedFilter] ? 'Update' : 'Add'} Filter
          </button>

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
