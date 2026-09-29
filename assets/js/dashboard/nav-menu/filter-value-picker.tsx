import React, { useState } from 'react'
import { useSiteContext } from '../site-context'
import { Filter, FilterClauseLabels } from '../dashboard-state'
import {
  EVENT_PROPS_PREFIX,
  getLabel,
  getPropertyKeyFromFilterKey,
  isFreeChoiceFilterOperation
} from '../util/filters'
import {
  getValueSuggestionsRequest,
  Suggestion
} from '../util/fetch-suggestions'
import { Combobox, ComboboxOption, isSameValue } from '../components/combobox'

export const FilterValuePicker = ({
  filter,
  labels,
  onChange
}: {
  filter: Filter
  labels: FilterClauseLabels
  onChange: (filter: Filter, labels?: FilterClauseLabels) => void
}) => {
  const site = useSiteContext()
  const [operation, filterKey, clauses] = filter
  const [pinned, setPinned] = useState<Suggestion[]>(() =>
    clauses.map((value) => ({
      value,
      label: getLabel(labels, filterKey, value)
    }))
  )

  const isSelected = (option: Suggestion) =>
    clauses.some((value) => isSameValue(value, option.value))

  const onSelect = (option: ComboboxOption) => {
    if (isSelected(option)) {
      onChange([
        operation,
        filterKey,
        clauses.filter((value) => !isSameValue(value, option.value))
      ])
      return
    }
    if (option.freeChoice) {
      setPinned((current) => [
        ...current,
        { value: option.value, label: option.label }
      ])
    }
    onChange([operation, filterKey, [...clauses, option.value]], {
      [option.value]: option.label
    })
  }

  return (
    <Combobox
      request={getValueSuggestionsRequest(site, filter)}
      pinned={pinned}
      multiple
      freeChoice={isFreeChoiceFilterOperation(operation)}
      isSelected={isSelected}
      onSelect={onSelect}
      label={
        filterKey.startsWith(EVENT_PROPS_PREFIX)
          ? `Values for ${getPropertyKeyFromFilterKey(filterKey)}`
          : 'Values'
      }
      focusOnMount
    />
  )
}
