import React from "react";
import { withRouter, Link } from 'react-router-dom'

import Modal from './modal'
import { parseQuery, formattedFilters } from '../../query'

class FilterModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      query: parseQuery(props.location.search, props.site),
      selectedFilter: this.props.match.params.field || "",
      updatedValue: "",
      negated: false
    }

    this.editableGoals = Object.keys(this.state.query.filters).filter(filter => !['goal', 'props'].includes(filter))
  }

  componentDidMount() {

  }

  renderBody() {
    const { selectedFilter, negated, updatedValue, query } = this.state;

    const updatedQuery = new URLSearchParams(window.location.search)
    const finalFilterValue = (['page', 'entry_page', 'exit_page'].includes(selectedFilter) && negated ? '!' : '') + updatedValue
    const validQuery = this.editableGoals.includes(selectedFilter) && updatedValue
    updatedQuery.set(selectedFilter, finalFilterValue)

    return (
      <React.Fragment>
        <h1 className="text-xl font-bold dark:text-gray-100">{query.filters[selectedFilter] ? 'Edit' : 'Add'} a Filter</h1>

        <div className="my-4 border-b border-gray-300"></div>
        <main className="modal__content flex flex-col">
          <select
            value={selectedFilter}
            className="block w-full py-2 pl-3 pr-10 mt-1 text-base border-gray-300 dark:border-gray-700 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:bg-gray-900 dark:text-gray-300"
            placeholder="Select a Filter"
            onChange={(e) => {
              const negated = query.filters[e.target.value][0] == '!' && ['page', 'entry_page', 'exit_page'].includes(e.target.value)
              const updatedValue = negated ? query.filters[e.target.value].slice(1) : (query.filters[e.target.value] || "")
              this.setState({ selectedFilter: e.target.value, updatedValue, negated })
            }}
          >
            <option disabled value="" className="hidden">Select a Filter</option>
            {this.editableGoals.map(filter => <option key={filter} value={filter}>{formattedFilters[filter]}</option>)}
          </select>

          {['page', 'entry_page', 'exit_page'].includes(selectedFilter) &&
            <div className="my-4 flex items-center">
              <label className="text-gray-700 dark:text-gray-300 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  className={`${negated ? 'bg-indigo-600' : 'bg-gray-200 dark:bg-gray-700'} mr-2 relative inline-flex flex-shrink-0 h-6 w-8 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none focus:ring`}
                  checked={negated}
                  name="exclude"
                  onClick={(e) => this.setState({ negated: e.target.checked })}
                />
                Exclude pages matching this filter
              </label>
            </div>
          }

          {selectedFilter &&
            <input
              type="text"
              className="bg-gray-100 dark:bg-gray-900 outline-none appearance-none border border-transparent rounded w-full p-2 text-gray-700 dark:text-gray-300 leading-normal focus:outline-none focus:bg-white dark:focus:bg-gray-800 focus:border-gray-300 dark:focus:border-gray-500"
              value={updatedValue}
              placeholder="Filter value"
              onChange={(e) => { this.setState({ updatedValue: e.target.value }) }}
            />
          }

          <Link to={{ pathname: `/${encodeURIComponent(this.props.site.domain)}`, search: updatedQuery.toString() }}
            className={"relative button my-4 w-2/3"}
          >
            {query.filters[selectedFilter] ? 'Update' : 'Add'} Filter
          </Link>

        </main>
      </React.Fragment>
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
