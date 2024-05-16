import React, { useMemo } from "react"

import FilterTypeSelector from "../../components/filter-type-selector"
import Combobox from '../../components/combobox'

import { isFreeChoiceFilter } from "../../util/filters"
import * as api from '../../api'
import { apiPath } from '../../util/url'
import { formattedFilters, FILTER_OPERATIONS } from '../../util/filters'

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
    [filter, filterKey]
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
    if (operation === FILTER_OPERATIONS.contains) {return Promise.resolve([])}

    const updatedQuery = queryForSuggestions(query, filter)
    return api.get(apiPath(site, `/suggestions/${filterKey}`), updatedQuery, { q: input.trim() })
  }

  function queryForSuggestions(query, filter) {
    let filters = query.filters
    const [_operation, filterKey, clauses] = filter
    if (clauses.length > 0) {
      filters = filters.concat([[FILTER_OPERATIONS.isNot, filterKey, clauses]])
    }
    return { ...query, filters }
  }

  return (
    <div className="grid grid-cols-11 mt-1">
      <div className="col-span-3 mr-2">
        <FilterTypeSelector
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

function getLabel(labels, filterKey, value) {
  if (['country', 'region', 'city'].includes(filterKey)) {
    return labels[filterKey][value]
  } else {
    return value
  }
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${word}`
  } if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return `an ${word}`
  }
  return `a ${word}`
}
