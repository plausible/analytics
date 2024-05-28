import React, { useMemo } from "react"

import FilterOperatorSelector from "../../components/filter-operator-selector"
import Combobox from '../../components/combobox'

import { FILTER_OPERATIONS, fetchSuggestions } from "../../util/filters"
import { apiPath } from '../../util/url'
import { getLabel } from '../../util/filters'

export default function FilterModalRow({
  site,
  query,
  filter,
  labels,
  onUpdate
}) {
  const selectedClauses = useMemo(
    () => filter.clauses.map((value) => ({ value, label: getLabel(labels, filter.key, value) })),
    [filter, labels]
  )

  function onComboboxSelect(selection) {
    const newClauses = selection.map(({ value }) => value)
    const newLabels = Object.fromEntries(selection.map(({ label, value }) => [value, label]))

    onUpdate(
      filter.updateClauses(newClauses),
      newLabels
    )
  }

  function fetchOptions(input) {
    if (filter.operation === FILTER_OPERATIONS.contains) {
      return Promise.resolve([])
    }

    return fetchSuggestions(apiPath(site, `/suggestions/${filter.key}`), query, input, [
      FILTER_OPERATIONS.isNot, filter.key, filter.clauses
    ])
  }

  return (
    <div className="grid grid-cols-11 mt-1">
      <div className="col-span-3 mr-2">
        <FilterOperatorSelector
          forFilter={filter.key}
          onSelect={(newOperation) => onUpdate(filter.updateOperation(newOperation), labels)}
          selectedType={filter.operation}
        />
      </div>
      <div className="col-span-8">
        <Combobox
          fetchOptions={fetchOptions}
          freeChoice={filter.isFreeChoice()}
          values={selectedClauses}
          onSelect={onComboboxSelect}
          placeholder={`Select ${withIndefiniteArticle(filter.displayName())}`}
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
