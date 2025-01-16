/** @format */

import React, { useMemo } from 'react'
import { TrashIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

import FilterOperatorSelector from '../../components/filter-operator-selector'
import Combobox from '../../components/combobox'

import {
  FILTER_OPERATIONS,
  fetchSuggestions,
  isFreeChoiceFilterOperation,
  getLabel,
  formattedFilters
} from '../../util/filters'
import { apiPath } from '../../util/url'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'

export default function FilterModalRow({ filter, labels, canDelete, showDelete, onUpdate, onDelete }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const [operation, filterKey, clauses] = filter

  const selectedClauses = useMemo(
    () =>
      clauses.map((value) => ({
        value,
        label: getLabel(labels, filterKey, value)
      })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [filter, labels]
  )

  function onComboboxSelect(selection) {
    const newClauses = selection.map(({ value }) => value)
    const newLabels = Object.fromEntries(
      selection.map(({ label, value }) => [value, label])
    )

    onUpdate([operation, filterKey, newClauses], newLabels)
  }

  function fetchOptions(input) {
    if (
      [FILTER_OPERATIONS.contains, FILTER_OPERATIONS.contains_not].includes(
        operation
      )
    ) {
      return Promise.resolve([])
    }

    let additionalFilter = null

    if (filterKey !== 'goal') {
      additionalFilter = [FILTER_OPERATIONS.isNot, filterKey, clauses]
    }

    return fetchSuggestions(
      apiPath(site, `/suggestions/${filterKey}`),
      query,
      input,
      additionalFilter
    )
  }

  return (
    <div className={classNames("grid mt-1", { "grid-cols-12": canDelete, "grid-cols-11": !canDelete })}>
      <div className="col-span-3">
        <FilterOperatorSelector
          forFilter={filterKey}
          onSelect={(newOperation) =>
            onUpdate([newOperation, filterKey, clauses], labels)
          }
          selectedType={operation}
        />
      </div>
      <div className="col-span-8 ml-2">
        <Combobox
          fetchOptions={fetchOptions}
          freeChoice={isFreeChoiceFilterOperation(operation)}
          values={selectedClauses}
          onSelect={onComboboxSelect}
          placeholder={`Select ${withIndefiniteArticle(formattedFilters[filterKey])}`}
        />
      </div>
      {showDelete && (
        <div className="col-span-1 flex flex-col justify-center">
          {/* eslint-disable-next-line jsx-a11y/anchor-is-valid */}
          <a
            className="ml-2 text-red-600 h-5 w-5 cursor-pointer"
            onClick={onDelete}
          >
            <TrashIcon />
          </a>
        </div>
      )}
    </div>
  )
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${word}`
  }
  if (
    ['a', 'e', 'i', 'o', 'u'].some((vowel) =>
      word.toLowerCase().startsWith(vowel)
    )
  ) {
    return `an ${word}`
  }
  return `a ${word}`
}
