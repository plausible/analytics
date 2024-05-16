import React from "react";
import { withRouter } from 'react-router-dom'

import { EVENT_PROPS_PREFIX, FILTER_GROUPS, formatFilterGroup, FILTER_OPERATIONS, filterType} from '../../util/filters'
import { parseQuery } from '../../query'
import { siteBasePath, PlausibleSearchParams } from '../../util/url'
import { shouldIgnoreKeypress } from '../../keybinding'
import { cleanLabels } from "../../util/filters"
import FilterModalGroup from "./filter-modal-group"

function partitionFilters(filterGroup, filters) {
  const otherFilters = []
  const filterState = {}
  let hasRelevantFilters = false

  filters.forEach((filter, index) => {
    const type = filterType(filter)
    if (FILTER_GROUPS[filterGroup].includes(type)) {
      const key = filterState[type] ? `${type}:${index}` : type
      filterState[key] = filter
      hasRelevantFilters = true
    } else {
      otherFilters.push(filter)
    }
  })

  FILTER_GROUPS[filterGroup].forEach((type) => {
    if (!filterState[type]) {
      filterState[type] = emptyFilter(type)
    }
  })

  return { filterState, otherFilters, hasRelevantFilters }
}

function emptyFilter(key) {
  const filterKey = key === 'props' ? EVENT_PROPS_PREFIX : key

  return [FILTER_OPERATIONS.is, filterKey, []]
}

class RegularFilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const { filterState, otherFilters, hasRelevantFilters } = partitionFilters(props.filterGroup, query.filters)

    this.handleKeydown = this.handleKeydown.bind(this)
    this.state = { query, filterState, labelState: query.labels, otherFilters, hasRelevantFilters }
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
    const filters = Object.values(this.state.filterState)
      .filter(([_op, _key, clauses]) => clauses.length > 0)
      .concat(this.state.otherFilters)

    this.selectFiltersAndCloseModal(filters)
  }

  isDisabled() {
    return Object.values(this.state.filterState).every(([_operation, _key, clauses]) => clauses.length === 0)
  }

  selectFiltersAndCloseModal(filters) {
    const queryString = new PlausibleSearchParams(window.location.search)
    queryString.set('filters', filters)
    queryString.set('labels', cleanLabels(filters, this.state.labelState))

    // :TODO: Use navigateToQuery or something similar
    this.props.history.replace({ pathname: siteBasePath(this.props.site), search: queryString.toString() })
  }

  onUpdateRowValue(id, newFilter, newLabels) {
    this.setState(prevState => {
      const [_operation, filterKey, _clauses] = newFilter
      return {
        filterState: {
          ...prevState.filterState,
          [id]: newFilter
        },
        labelState: cleanLabels(
          Object.values(this.state.filterState).concat(this.state.query.filters),
          prevState.labelState,
          filterKey,
          newLabels
        )
      }
    })
  }

  onAddRow(type) {
    this.setState(prevState => {
      const filter = emptyFilter(type)
      const id = `${type}${Object.keys(this.state.filterState).length}`

      return {
        filterState: {
          ...prevState.filterState,
          [id]: filter
        }
      }
    })
  }

  onDeleteRow(id) {
    this.setState(prevState => {
      const filterState = {...prevState.filterState}
      delete filterState[id]
      return { filterState }
    })
  }

  render() {
    const { filterGroup } = this.props

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Filter by {formatFilterGroup(filterGroup)}</h1>

        <div className="mt-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" onSubmit={this.handleSubmit.bind(this)}>
            {FILTER_GROUPS[this.props.filterGroup].map((type) => (
              <FilterModalGroup
                key={type}
                type={type}
                filterState={this.state.filterState}
                labels={this.state.labelState}
                site={this.props.site}
                query={this.state.query}
                onUpdateRowValue={this.onUpdateRowValue.bind(this)}
                onAddRow={this.onAddRow.bind(this)}
                onDeleteRow={this.onDeleteRow.bind(this)}
              />
            ))}

            <div className="mt-6 flex items-center justify-start">
              <button
                type="submit"
                className="button"
                disabled={this.isDisabled()}
              >
                Apply Filter
              </button>

              {this.state.hasRelevantFilters && (
                <button
                  type="button"
                  className="ml-2 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                  onClick={() => {
                    this.selectFiltersAndCloseModal(this.state.otherFilters)
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
