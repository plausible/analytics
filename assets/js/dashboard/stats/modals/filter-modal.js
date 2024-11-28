import React from 'react'
import { useMatch, useParams } from 'react-router-dom';

import Modal from './modal';
import { EVENT_PROPS_PREFIX, FILTER_GROUP_TO_MODAL_TYPE, formatFilterGroup, FILTER_OPERATIONS, getFilterGroup, FILTER_MODAL_TO_FILTER_GROUP, cleanLabels } from '../../util/filters';
import { useQueryContext } from '../../query-context';
import { useSiteContext } from '../../site-context';
import { isModifierPressed, isTyping } from '../../keybinding';
import FilterModalGroup from "./filter-modal-group";
import { editSegmentFilterRoute, editSegmentRoute, rootRoute } from '../../router';
import { useAppNavigate } from '../../navigation/use-app-navigate';
import { AllSegmentsModal } from '../../segments/segment-modals';

function partitionFilters(modalType, filters) {
  const otherFilters = []
  const filterState = {}
  let hasRelevantFilters = false

  filters.forEach((filter, index) => {
    const filterGroup = getFilterGroup(filter)
    if (FILTER_GROUP_TO_MODAL_TYPE[filterGroup] === modalType) {
      const key = filterState[filterGroup] ? `${filterGroup}:${index}` : filterGroup
      filterState[key] = filter
      hasRelevantFilters = true
    } else {
      otherFilters.push(filter)
    }
  })

  FILTER_MODAL_TO_FILTER_GROUP[modalType].forEach((filterGroup) => {
    if (!filterState[filterGroup]) {
      filterState[filterGroup] = emptyFilter(filterGroup)
    }
  })

  return { filterState, otherFilters, hasRelevantFilters }
}

function emptyFilter(key) {
  const filterKey = key === 'props' ? EVENT_PROPS_PREFIX : key

  return [FILTER_OPERATIONS.is, filterKey, []]
}

class FilterModal extends React.Component {
  constructor(props) {
    super(props)

    const modalType = this.props.modalType

    const query = this.props.query
    const { filterState, otherFilters, hasRelevantFilters } = partitionFilters(modalType, query.filters)

    this.handleKeydown = this.handleKeydown.bind(this)
    this.state = { query, filterState, labelState: query.labels, otherFilters, hasRelevantFilters }
  }

  componentDidMount() {
    document.addEventListener('keydown', this.handleKeydown)
  }

  componentWillUnmount() {
    document.removeEventListener('keydown', this.handleKeydown)
  }

  handleKeydown(e) {
    if (isTyping(e) || isModifierPressed(e)) return

    if (e.target.tagName === 'BODY' && e.key === 'Enter') {
      this.handleSubmit()
    }
  }

  handleSubmit(e) {
    const filters = Object.values(this.state.filterState)
      .filter(([_op, _key, clauses]) => clauses.length > 0)
      .concat(this.state.otherFilters)

    this.selectFiltersAndCloseModal(filters)
    e.preventDefault()
  }

  isDisabled() {
    return Object.values(this.state.filterState).every(([_operation, _key, clauses]) => clauses.length === 0)
  }

  selectFiltersAndCloseModal(filters) {
    this.props.navigate({
      ...this.props.applyFiltersTo,
      search: (search) => ({
        ...search,
        filters: filters,
        labels: cleanLabels(filters, this.state.labelState)
      }),
      replace: true
    })
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

  onAddRow(filterGroup) {
    this.setState((prevState) => {
      const filter = emptyFilter(filterGroup)
      const id = `${filterGroup}${Object.keys(this.state.filterState).length}`

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
      const filterState = { ...prevState.filterState }
      delete filterState[id]
      return { filterState }
    })
  }

  getFilterGroups() {
    const groups = FILTER_MODAL_TO_FILTER_GROUP[this.props.modalType]
    if (this.props.modalType === 'source' && !this.props.site.flags.channels) {
      return groups.filter((group) => group !== 'channel')
    }
    return groups
  }

  render() {
    return (
      <Modal maxWidth="460px" onClose={this.props.onClose}>
        <h1 className="text-xl font-bold dark:text-gray-100">
          Filter by {formatFilterGroup(this.props.modalType)}
        </h1>

        <div className="mt-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" onSubmit={this.handleSubmit.bind(this)}>
            {this.getFilterGroups().map((filterGroup) => (
              <FilterModalGroup
                key={filterGroup}
                filterGroup={filterGroup}
                filterState={this.state.filterState}
                labels={this.state.labelState}
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
                  Remove filter{FILTER_MODAL_TO_FILTER_GROUP[this.props.modalType].length > 1 ? 's' : ''}
                </button>
              )}
            </div>
          </form>
        </main>
      </Modal>
    )
  }
}

export default function FilterModalWithRouter() {
  const navigate = useAppNavigate();
  const { field } = useParams()
  const { query } = useQueryContext()
  const site = useSiteContext()
  const match = useMatch(editSegmentFilterRoute)
  if (field === 'segments') {
    return <AllSegmentsModal />
  }
  return (
    <FilterModal
      applyFiltersTo={
        match
          ? { path: `/${editSegmentRoute.path}`, params: { id: match.params.id } }
          : { path: rootRoute.path, replace: true }
      }
      onClose={
        match
          ? () =>
              navigate({
                path: `/${editSegmentRoute.path}`,
                params: { id: match.params.id },
                search: (s) => s
              })
          : undefined
      }
      modalType={field || 'page'}
      query={query}
      navigate={navigate}
      site={site}
    />
  )
}
