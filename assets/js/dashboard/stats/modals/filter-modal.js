import React from 'react'
import { useParams } from 'react-router-dom'

import { ModalLayout, ModalFooter } from '../../components/modal-layout'
import {
  EVENT_PROPS_PREFIX,
  formattedFilters,
  FILTER_OPERATIONS,
  getFilterDimension,
  cleanLabels,
  getAvailableFilterDimensions
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { isModifierPressed, isTyping } from '../../keybinding'
import FilterModalDimension from './filter-modal-dimension'
import { rootRoute } from '../../router'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { Button } from '../../components/button'

function partitionFilters(dimension, filters) {
  const otherFilters = []
  const filterState = {}
  let filtersToRemoveCount = 0

  filters.forEach((filter, index) => {
    if (getFilterDimension(filter) === dimension) {
      const key = filterState[dimension] ? `${dimension}:${index}` : dimension
      filterState[key] = filter
      filtersToRemoveCount++
    } else {
      otherFilters.push(filter)
    }
  })

  if (!filterState[dimension]) {
    filterState[dimension] = emptyFilter(dimension)
  }

  return { filterState, otherFilters, filtersToRemoveCount }
}

function emptyFilter(key) {
  const filterKey = key === 'props' ? EVENT_PROPS_PREFIX : key

  return [FILTER_OPERATIONS.is, filterKey, []]
}

class FilterModal extends React.Component {
  constructor(props) {
    super(props)

    const dashboardState = this.props.dashboardState
    const { filterState, otherFilters, filtersToRemoveCount } =
      partitionFilters(this.props.dimension, dashboardState.filters)

    this.handleKeydown = this.handleKeydown.bind(this)
    this.closeModal = this.closeModal.bind(this)
    this.state = {
      dashboardState,
      filterState,
      labelState: dashboardState.labels,
      otherFilters,
      filtersToRemoveCount
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

  render() {
    return (
      <ModalLayout
        title={`Filter by ${formattedFilters[this.props.dimension]}`}
        onClose={this.closeModal}
      >
        <form
          className="flex flex-col gap-y-6"
          onSubmit={this.handleSubmit.bind(this)}
        >
          <div className="flex flex-col gap-y-3 mb-2">
            <FilterModalDimension
              dimension={this.props.dimension}
              filterState={this.state.filterState}
              labels={this.state.labelState}
              onUpdateRowValue={this.onUpdateRowValue.bind(this)}
              onAddRow={this.onAddRow.bind(this)}
              onDeleteRow={this.onDeleteRow.bind(this)}
            />
          </div>

          <ModalFooter>
            {this.state.filtersToRemoveCount > 0 ? (
              <Button
                theme="secondary"
                size="sm"
                onClick={() => {
                  this.selectFiltersAndCloseModal(this.state.otherFilters)
                }}
              >
                {this.state.filtersToRemoveCount > 1
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
  if (
    field === 'segment' ||
    !getAvailableFilterDimensions(site).includes(field)
  ) {
    return null
  }
  return (
    <FilterModal
      {...props}
      dimension={field}
      dashboardState={dashboardState}
      navigate={navigate}
      site={site}
    />
  )
}
