import React, { useMemo } from "react"

import FilterOperatorSelector from "../../components/filter-operator-selector"
import Combobox from '../../components/combobox'

import { FILTER_OPERATIONS, fetchSuggestions, isFreeChoiceFilter } from "../../util/filters"
import { apiPath } from '../../util/url'
import { getLabel, formattedFilters } from '../../util/filters'

export default function FilterModalRow({
  site,
  query,
  filter,
  labels,
  onUpdate
}) {
  const [operation, filterKey, clauses] = filter

  const selectedClauses = useMemo(
    () => clauses.map((value) => ({ value, label: getLabel(labels, filterKey, value) })),
    [filter, labels]
  )

  function onComboboxSelect(selection) {
    const newClauses = selection.map(({ value }) => value)
    const newLabels = Object.fromEntries(selection.map(({ label, value }) => [value, label]))

    onUpdate(
      [operation, filterKey, newClauses],
      newLabels
    )
  }

  function fetchOptions(input) {
    if ([FILTER_OPERATIONS.contains, FILTER_OPERATIONS.does_not_contain].includes(operation)) {
      return Promise.resolve([])
    }

    return fetchSuggestions(apiPath(site, `/suggestions/${filterKey}`), query, input, [
      FILTER_OPERATIONS.isNot, filterKey, clauses
    ])
  }

  return (
    <div className="grid grid-cols-11 mt-1">
      <div className="col-span-3 mr-2">
        <FilterOperatorSelector
          forFilter={filterKey}
          onSelect={(newOperation) => onUpdate([newOperation, filterKey, clauses], labels)}
          selectedType={operation}
        />
      </div>
      <div className="col-span-8">
        <Combobox
          fetchOptions={fetchOptions}
          freeChoice={isFreeChoiceFilter(filterKey)}
          values={selectedClauses}
          onSelect={onComboboxSelect}
          placeholder={`Select ${withIndefiniteArticle(formattedFilters[filterKey])}`}
        />
      </div>
    </div>
  )
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${word}`
  } if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return `an ${word}`
  }
  return `a ${word}`
}
