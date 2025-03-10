import React from 'react'
import { useParams } from 'react-router-dom';

import Modal from './modal';
import { EVENT_PROPS_PREFIX, FILTER_GROUP_TO_MODAL_TYPE, formatFilterGroup, FILTER_OPERATIONS, getFilterGroup, FILTER_MODAL_TO_FILTER_GROUP, cleanLabels, getAvailableFilterModals } from '../../util/filters';
import { useQueryContext } from '../../query-context';
import { useSiteContext } from '../../site-context';
import { isModifierPressed, isTyping } from '../../keybinding';
import FilterModalGroup from "./filter-modal-group";
import { rootRoute } from '../../router';
import { useAppNavigate } from '../../navigation/use-app-navigate';
import { SegmentModal } from '../../segments/segment-modals';
import { TrashIcon } from '@heroicons/react/24/outline';
import { isSegmentFilter } from '../../filtering/segments';

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
      path: rootRoute.path,
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
    return groups
  }

  render() {
    return (
      <Modal maxWidth="460px">
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
                Apply filter
              </button>

              {this.state.hasRelevantFilters && (
                <button
                  type="button"
                  className="ml-4 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                  onClick={() => {
                    this.selectFiltersAndCloseModal(this.state.otherFilters)
                  }}
                >
                  <TrashIcon className="w-4 h-4 mr-2" />
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

export default function FilterModalWithRouter(props) {
  const navigate = useAppNavigate();
  const { field } = useParams()
  const { query } = useQueryContext()
  const site = useSiteContext()
  if (!Object.keys(getAvailableFilterModals(site)).includes(field)) {
    return null
  }
  const firstSegmentFilter = field === 'segment' ? query.filters?.find(isSegmentFilter) : null
  if (firstSegmentFilter) {
    const firstSegmentId = firstSegmentFilter[2][0]
    return <SegmentModal id={firstSegmentId} />
  }
  return (
    <FilterModal
      {...props}
      modalType={field || 'page'}
      query={query}
      navigate={navigate}
      site={site}
    />
  )
}
