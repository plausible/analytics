import React from 'react'
import { useParams } from 'react-router-dom'

import { ModalLayout, ModalFooter } from '../../components/modal-layout'
import {
  EVENT_PROPS_PREFIX,
  FILTER_GROUP_TO_MODAL_TYPE,
  formatFilterGroup,
  FILTER_OPERATIONS,
  getFilterGroup,
  FILTER_MODAL_TO_FILTER_GROUP,
  cleanLabels,
  getAvailableFilterModals
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { isModifierPressed, isTyping } from '../../keybinding'
import FilterModalGroup from './filter-modal-group'
import { rootRoute } from '../../router'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { SegmentModal } from '../../segments/segment-modals'
import { findAppliedSegmentFilter } from '../../filtering/segments'
import { Button } from '../../components/button'

function partitionFilters(modalType, filters) {
  const otherFilters = []
  const filterState = {}
  let hasRelevantFilters = false

  filters.forEach((filter, index) => {
    const filterGroup = getFilterGroup(filter)
    if (FILTER_GROUP_TO_MODAL_TYPE[filterGroup] === modalType) {
      const key = filterState[filterGroup]
        ? `${filterGroup}:${index}`
        : filterGroup
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

    const dashboardState = this.props.dashboardState
    const { filterState, otherFilters, hasRelevantFilters } = partitionFilters(
      modalType,
      dashboardState.filters
    )

    this.handleKeydown = this.handleKeydown.bind(this)
    this.closeModal = this.closeModal.bind(this)
    this.state = {
      dashboardState,
      filterState,
      labelState: dashboardState.labels,
      otherFilters,
      hasRelevantFilters
    }
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
    return Object.values(this.state.filterState).every(
      ([_operation, _key, clauses]) => clauses.length === 0
    )
  }

  closeModal() {
    this.props.navigate({
      path: rootRoute.path,
      search: (search) => search
    })
  }

  selectFiltersAndCloseModal(filters) {
    this.props.navigate({
      path: rootRoute.path,
      search: (searchRecord) => ({
        ...searchRecord,
        filters: filters,
        labels: cleanLabels(filters, this.state.labelState)
      }),
      replace: true
    })
  }

  onUpdateRowValue(id, newFilter, newLabels) {
    this.setState((prevState) => {
      const [_operation, filterKey, _clauses] = newFilter
      return {
        filterState: {
          ...prevState.filterState,
          [id]: newFilter
        },
        labelState: cleanLabels(
          Object.values(this.state.filterState).concat(
            this.state.dashboardState.filters
          ),
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
    this.setState((prevState) => {
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
      <ModalLayout
        title={`Filter by ${formatFilterGroup(this.props.modalType)}`}
        onClose={this.closeModal}
      >
        <form
          className="flex flex-col gap-y-6"
          onSubmit={this.handleSubmit.bind(this)}
        >
          <div className="flex flex-col gap-y-3 mb-2">
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
          </div>

          <ModalFooter>
            {this.state.hasRelevantFilters ? (
              <Button
                theme="secondary"
                size="sm"
                onClick={() => {
                  this.selectFiltersAndCloseModal(this.state.otherFilters)
                }}
              >
                {FILTER_MODAL_TO_FILTER_GROUP[this.props.modalType].length > 1
                  ? 'Remove filters'
                  : 'Remove filter'}
              </Button>
            ) : (
              <Button
                type="button"
                theme="secondary"
                size="sm"
                onClick={this.closeModal}
              >
                Cancel
              </Button>
            )}

            <Button type="submit" size="sm" disabled={this.isDisabled()}>
              Apply filter
            </Button>
          </ModalFooter>
        </form>
      </ModalLayout>
    )
  }
}

export default function FilterModalWithRouter(props) {
  const navigate = useAppNavigate()
  const { field } = useParams()
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  if (!Object.keys(getAvailableFilterModals(site)).includes(field)) {
    return null
  }
  const appliedSegmentFilter =
    field === 'segment'
      ? findAppliedSegmentFilter({ filters: dashboardState.filters })
      : null
  if (appliedSegmentFilter) {
    const [_operation, _dimension, [segmentId]] = appliedSegmentFilter
    return <SegmentModal id={segmentId} />
  }
  return (
    <FilterModal
      {...props}
      modalType={field || 'page'}
      dashboardState={dashboardState}
      navigate={navigate}
      site={site}
    />
  )
}
